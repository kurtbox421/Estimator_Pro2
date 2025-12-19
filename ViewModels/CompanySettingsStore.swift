import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import Foundation
import UIKit

private enum CompanyStorage {
    static func fileName(for uid: String) -> String { "companySettings_\(uid).json" }
}

struct CompanySettings: Codable {
    var ownerID: String?
    var companyName: String
    var companyAddress: String
    var companyPhone: String
    var companyEmail: String
    var logoPath: String?

    private enum CodingKeys: String, CodingKey {
        case ownerID
        case companyName
        case companyAddress
        case companyPhone
        case companyEmail
        case logoPath
    }

    static let empty = CompanySettings(ownerID: nil, companyName: "", companyAddress: "", companyPhone: "", companyEmail: "", logoPath: nil)
}

final class CompanySettingsStore: ObservableObject {
    @Published var companyName: String = ""
    @Published var companyAddress: String = ""
    @Published var companyPhone: String = ""
    @Published var companyEmail: String = ""
    @Published var logoImage: UIImage?
    @Published private(set) var isUploadingLogo = false

    var settings: CompanySettings {
        CompanySettings(
            ownerID: currentUserID,
            companyName: companyName,
            companyAddress: companyAddress,
            companyPhone: companyPhone,
            companyEmail: companyEmail,
            logoPath: currentLogoPath
        )
    }

    private let persistence: PersistenceService
    private let db: Firestore
    private let storage: Storage
    private let auth: Auth
    private var cancellables: Set<AnyCancellable> = []
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUserID: String?
    private var currentLogoPath: String?
    private var isApplyingRemoteUpdate = false

    private func logoStoragePath(for uid: String) -> String {
        "users/\(uid)/branding/logo.png"
    }

    init(
        persistence: PersistenceService = .shared,
        database: Firestore = Firestore.firestore(),
        storage: Storage = Storage.storage(),
        auth: Auth = Auth.auth()
    ) {
        self.persistence = persistence
        self.db = database
        self.storage = storage
        self.auth = auth

        configureAuthListener()
        bindSaves()
    }

    deinit {
        listener?.remove()
        if let authHandle { auth.removeStateDidChangeListener(authHandle) }
    }

    private func bindSaves() {
        Publishers.CombineLatest4($companyName, $companyAddress, $companyPhone, $companyEmail)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] name, address, phone, email in
                guard let self, let uid = self.currentUserID, !self.isApplyingRemoteUpdate else { return }

                let settings = CompanySettings(
                    ownerID: uid,
                    companyName: name,
                    companyAddress: address,
                    companyPhone: phone,
                    companyEmail: email,
                    logoPath: self.currentLogoPath
                )

                self.persistence.save(settings, to: CompanyStorage.fileName(for: uid))

                do {
                    try self.companyDocument(for: uid).setData(from: settings)
                } catch {
                    print("Failed to save company settings: \(error.localizedDescription)")
                }
            }
            .store(in: &cancellables)
    }

    private func configureAuthListener() {
        authHandle = auth.addStateDidChangeListener { [weak self] _, user in
            self?.attachListener(for: user)
        }

        attachListener(for: auth.currentUser)
    }

    private func attachListener(for user: User?) {
        listener?.remove()
        currentUserID = user?.uid
        currentLogoPath = nil
        logoImage = nil
        apply(settings: .empty)

        guard let uid = user?.uid else { return }

        loadLocalSettings(for: uid)
        loadCachedLogo(for: uid)

        listener = companyDocument(for: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error { print("Failed to fetch company settings: \(error.localizedDescription)"); return }

                guard let data = try? snapshot?.data(as: CompanySettings.self) else { return }

                DispatchQueue.main.async {
                    self.apply(settings: data)
                }
            }
    }

    private func loadLocalSettings(for uid: String) {
        if let stored: CompanySettings = persistence.load(CompanySettings.self, from: CompanyStorage.fileName(for: uid)) {
            apply(settings: stored)
        }
    }

    private func apply(settings: CompanySettings) {
        isApplyingRemoteUpdate = true
        companyName = settings.companyName
        companyAddress = settings.companyAddress
        companyPhone = settings.companyPhone
        companyEmail = settings.companyEmail
        currentLogoPath = settings.logoPath

        if let uid = currentUserID, let logoPath = settings.logoPath {
            fetchLogoIfNeeded(from: logoPath, for: uid)
        }
        isApplyingRemoteUpdate = false
    }

    private func companyDocument(for uid: String) -> DocumentReference {
        db.collection("users")
            .document(uid)
            .collection("company")
            .document("settings")
    }

    // MARK: - Branding & Logo

    @MainActor
    func uploadLogo(data: Data) async {
        guard let uid = currentUserID else { return }

        isUploadingLogo = true
        defer { isUploadingLogo = false }

        do {
            let path = logoStoragePath(for: uid)
            let ref = storage.reference(withPath: path)
            let metadata = StorageMetadata()
            metadata.contentType = "image/png"

            _ = try await ref.putDataAsync(data, metadata: metadata)

            logoImage = UIImage(data: data)
            CompanyLogoLoader.cacheLogoData(data, for: uid)
            currentLogoPath = path

            var updatedSettings = settings
            updatedSettings.logoPath = path
            do {
                try companyDocument(for: uid).setData(from: updatedSettings, merge: true)
            } catch {
                print("Failed to save logo path: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to upload logo: \(error.localizedDescription)")
        }
    }

    @MainActor
    func removeLogo() async {
        guard let uid = currentUserID else { return }

        isUploadingLogo = true
        defer { isUploadingLogo = false }

        do {
            if let currentLogoPath {
                let ref = storage.reference(withPath: currentLogoPath)
                try await ref.delete()
            }
        } catch {
            print("Failed to remove logo: \(error.localizedDescription)")
        }

        currentLogoPath = nil
        logoImage = nil
        CompanyLogoLoader.clearCache(for: uid)

        var updatedSettings = settings
        updatedSettings.logoPath = nil
        persistence.save(updatedSettings, to: CompanyStorage.fileName(for: uid))

        do {
            try companyDocument(for: uid).setData(from: updatedSettings, merge: true)
        } catch {
            print("Failed to clear logo path: \(error.localizedDescription)")
        }
    }

    private func fetchLogoIfNeeded(from path: String, for uid: String) {
        guard path != currentLogoPath || logoImage == nil else { return }
        if let cached = CompanyLogoLoader.loadLogo(for: uid) {
            logoImage = cached
            return
        }

        let ref = storage.reference(withPath: path)
        ref.getData(maxSize: 5 * 1024 * 1024) { [weak self] data, error in
            guard let self else { return }
            if let error { print("Failed to download logo: \(error.localizedDescription)"); return }
            guard let data, let image = UIImage(data: data) else { return }

            DispatchQueue.main.async {
                self.logoImage = image
                CompanyLogoLoader.cacheLogoData(data, for: uid)
            }
        }
    }

    private func loadCachedLogo(for uid: String) {
        if let cached = CompanyLogoLoader.loadLogo(for: uid) {
            logoImage = cached
        }
    }
}
