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

@MainActor
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
    private let session: SessionManager
    private var cancellables: Set<AnyCancellable> = []
    private var listener: ListenerRegistration?
    private var userListener: ListenerRegistration?
    private var resetToken: UUID?
    private var currentUserID: String?
    private var currentLogoPath: String?
    private var currentLogoURL: String?
    private var isApplyingRemoteUpdate = false
    private let brandingLogoField = "brandingLogoURL"

    private enum LogoUploadError: LocalizedError {
        case missingUser
        case invalidImageData

        var errorDescription: String? {
            switch self {
            case .missingUser:
                return "You must be signed in to upload a logo."
            case .invalidImageData:
                return "We couldn’t process that image. Please try a different file."
            }
        }
    }

    init(
        persistence: PersistenceService = .shared,
        database: Firestore = Firestore.firestore(),
        storage: Storage = Storage.storage(),
        auth: Auth = Auth.auth(),
        session: SessionManager
    ) {
        self.persistence = persistence
        self.db = database
        self.storage = storage
        self.auth = auth
        self.session = session

        resetToken = session.registerResetHandler { [weak self] in
            self?.clear()
        }
        session.$uid
            .receive(on: RunLoop.main)
            .sink { [weak self] uid in
                self?.setUser(uid)
            }
            .store(in: &cancellables)
        setUser(session.uid)
        bindSaves()
    }

    deinit {
        Task { @MainActor in
            listener?.remove()
            userListener?.remove()
            cancellables.removeAll()
            if let resetToken {
                session.unregisterResetHandler(resetToken)
            }
        }
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

                print("[Data] CompanySettingsStore uid=\(uid) path=local:\(CompanyStorage.fileName(for: uid)) action=save")
                self.persistence.save(settings, to: CompanyStorage.fileName(for: uid))

                do {
                    let path = "users/\(uid)/company/settings"
                    print("[Data] CompanySettingsStore uid=\(uid) path=\(path) action=write")
                    try self.companyDocument(for: uid).setData(from: settings)
                } catch {
                    print("Failed to save company settings: \(error.localizedDescription)")
                }
            }
            .store(in: &cancellables)
    }

    private func setUser(_ uid: String?) {
        listener?.remove()
        userListener?.remove()
        currentUserID = uid
        currentLogoPath = nil
        currentLogoURL = nil
        logoImage = nil
        apply(settings: .empty)

        guard let uid else { return }

        loadLocalSettings(for: uid)
        loadCachedLogo(for: uid)
        attachUserListener(for: uid)

        let path = "users/\(uid)/company/settings"
        print("[Data] CompanySettingsStore uid=\(uid) path=\(path) action=listen")

        listener = companyDocument(for: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error { print("Failed to fetch company settings: \(error.localizedDescription)"); return }

                guard let data = try? snapshot?.data(as: CompanySettings.self) else { return }

                DispatchQueue.main.async {
                    self.apply(settings: data)
                }
            }

        session.track(listener)
    }

    private func loadLocalSettings(for uid: String) {
        print("[Data] CompanySettingsStore uid=\(uid) path=local:\(CompanyStorage.fileName(for: uid)) action=load")
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
        isApplyingRemoteUpdate = false
    }

    private func companyDocument(for uid: String) -> DocumentReference {
        db.collection("users")
            .document(uid)
            .collection("company")
            .document("settings")
    }

    private func userDocument(for uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    // MARK: - Branding & Logo

    @MainActor
    func fetchBrandingLogo() async {
        guard let uid = auth.currentUser?.uid else {
            print("Failed to fetch branding logo URL: missing user")
            return
        }

        do {
            let path = "users/\(uid)"
            print("[Data] CompanySettingsStore uid=\(uid) path=\(path) action=fetch-logo-url")
            let snapshot = try await userDocument(for: uid).getDocument()
            let logoURL = snapshot.data()?[brandingLogoField] as? String
            handleLogoURLChange(logoURL, for: uid)
        } catch {
            print("Failed to fetch branding logo URL: \(error)")
        }
    }

    @MainActor
    func uploadLogo(data: Data) async throws {
        guard let uid = auth.currentUser?.uid else {
            let error = LogoUploadError.missingUser
            print("Failed to upload logo: \(error)")
            throw error
        }

        isUploadingLogo = true
        defer { isUploadingLogo = false }

        do {
            let path = "branding/\(uid)/logo.jpg"
            let ref = storage.reference(withPath: path)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await ref.putDataAsync(data, metadata: metadata)

            guard let logoImage = UIImage(data: data) else {
                let error = LogoUploadError.invalidImageData
                print("Failed to upload logo: \(error)")
                throw error
            }

            let downloadURL = try await ref.downloadURL()
            print("Uploaded logo to \(path)")
            print("[Data] CompanySettingsStore uid=\(uid) path=users/\(uid) action=write-branding-logo")
            try await userDocument(for: uid).setData([
                brandingLogoField: downloadURL.absoluteString,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            self.logoImage = logoImage
            CompanyLogoLoader.cacheLogoData(data, for: uid)
            currentLogoURL = downloadURL.absoluteString
            currentLogoPath = path
        } catch {
            print("Failed to upload logo: \(error)")
            throw error
        }
    }

    @MainActor
    func removeLogo() async {
        guard let uid = auth.currentUser?.uid else { return }

        isUploadingLogo = true
        defer { isUploadingLogo = false }

        do {
            let path = "branding/\(uid)/logo.jpg"
            let ref = storage.reference(withPath: path)
            try await ref.delete()
        } catch {
            print("Failed to remove logo: \(error)")
        }

        currentLogoPath = nil
        currentLogoURL = nil
        logoImage = nil
        CompanyLogoLoader.clearCache(for: uid)

        var updatedSettings = settings
        updatedSettings.logoPath = nil
        persistence.save(updatedSettings, to: CompanyStorage.fileName(for: uid))

        do {
            print("[Data] CompanySettingsStore uid=\(uid) path=users/\(uid)/company/settings action=write")
            try companyDocument(for: uid).setData(from: updatedSettings, merge: true)
            try await userDocument(for: uid).setData([
                brandingLogoField: FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("Failed to clear logo path: \(error)")
        }
    }

    private func loadCachedLogo(for uid: String) {
        if let cached = CompanyLogoLoader.loadLogo(for: uid) {
            logoImage = cached
        }
    }

    private func attachUserListener(for uid: String) {
        let path = "users/\(uid)"
        print("[Data] CompanySettingsStore uid=\(uid) path=\(path) action=listen-branding")
        userListener = userDocument(for: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("Failed to fetch branding logo URL: \(error)")
                    return
                }

                let logoURL = snapshot?.data()?[self.brandingLogoField] as? String
                handleLogoURLChange(logoURL, for: uid)
            }

        session.track(userListener)
    }

    private func handleLogoURLChange(_ logoURL: String?, for uid: String) {
        guard logoURL != currentLogoURL else { return }
        currentLogoURL = logoURL

        guard let logoURL, let url = URL(string: logoURL) else {
            logoImage = nil
            CompanyLogoLoader.clearCache(for: uid)
            return
        }

        CompanyLogoLoader.clearCache(for: uid)

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }
                await MainActor.run {
                    self.logoImage = image
                    CompanyLogoLoader.cacheLogoData(data, for: uid)
                }
            } catch {
                print("Failed to download logo: \(error)")
            }
        }
    }

    func clear() {
        listener?.remove()
        userListener?.remove()
        listener = nil
        userListener = nil
        currentUserID = nil
        currentLogoPath = nil
        currentLogoURL = nil
        logoImage = nil
        apply(settings: .empty)
    }
}
