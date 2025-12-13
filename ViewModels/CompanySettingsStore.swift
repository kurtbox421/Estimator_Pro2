import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation

private enum CompanyStorage {
    static func fileName(for uid: String) -> String { "companySettings_\(uid).json" }
}

struct CompanySettings: Codable {
    var ownerID: String?
    var companyName: String
    var companyAddress: String
    var companyPhone: String
    var companyEmail: String

    private enum CodingKeys: String, CodingKey {
        case ownerID
        case companyName
        case companyAddress
        case companyPhone
        case companyEmail
    }

    static let empty = CompanySettings(ownerID: nil, companyName: "", companyAddress: "", companyPhone: "", companyEmail: "")
}

final class CompanySettingsStore: ObservableObject {
    @Published var companyName: String = ""
    @Published var companyAddress: String = ""
    @Published var companyPhone: String = ""
    @Published var companyEmail: String = ""

    var settings: CompanySettings {
        CompanySettings(
            ownerID: currentUserID,
            companyName: companyName,
            companyAddress: companyAddress,
            companyPhone: companyPhone,
            companyEmail: companyEmail
        )
    }

    private let persistence: PersistenceService
    private let db: Firestore
    private let auth: Auth
    private var cancellables: Set<AnyCancellable> = []
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUserID: String?
    private var isApplyingRemoteUpdate = false

    init(
        persistence: PersistenceService = .shared,
        database: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth()
    ) {
        self.persistence = persistence
        self.db = database
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
                    companyEmail: email
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
        apply(settings: .empty)

        guard let uid = user?.uid else { return }

        loadLocalSettings(for: uid)

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
        isApplyingRemoteUpdate = false
    }

    private func companyDocument(for uid: String) -> DocumentReference {
        db.collection("users")
            .document(uid)
            .collection("company")
            .document("settings")
    }
}
