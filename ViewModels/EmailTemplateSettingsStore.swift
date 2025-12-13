import Combine
import FirebaseAuth
import Foundation

private enum EmailTemplateStorage {
    static func fileName(for uid: String) -> String { "emailTemplateSettings_\(uid).json" }
}

struct EmailTemplateSettings: Codable {
    var defaultEmailMessage: String

    static let standard = EmailTemplateSettings(
        defaultEmailMessage: """
Hi,

Attached is your estimate/invoice. Let me know if you have any questions.

Thanks!
"""
    )

    enum CodingKeys: String, CodingKey {
        case defaultEmailMessage
        case defaultEmailSubject
        case defaultEmailBody
    }

    init(defaultEmailMessage: String) {
        self.defaultEmailMessage = defaultEmailMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let message = try container.decodeIfPresent(String.self, forKey: .defaultEmailMessage) {
            defaultEmailMessage = message
            return
        }

        let legacySubject = try container.decodeIfPresent(String.self, forKey: .defaultEmailSubject) ?? ""
        let legacyBody = try container.decodeIfPresent(String.self, forKey: .defaultEmailBody) ?? ""

        let subject = legacySubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = legacyBody.trimmingCharacters(in: .whitespacesAndNewlines)

        if subject.isEmpty && body.isEmpty {
            defaultEmailMessage = EmailTemplateSettings.standard.defaultEmailMessage
        } else if subject.isEmpty {
            defaultEmailMessage = body
        } else if body.isEmpty {
            defaultEmailMessage = subject
        } else {
            defaultEmailMessage = subject + "\n\n" + body
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultEmailMessage, forKey: .defaultEmailMessage)
    }
}

final class EmailTemplateSettingsStore: ObservableObject {
    @Published var defaultEmailMessage: String

    private let persistence: PersistenceService
    private let auth: Auth
    private var cancellables: Set<AnyCancellable> = []
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUserID: String?
    private var isApplyingRemoteUpdate = false

    init(persistence: PersistenceService = .shared, auth: Auth = Auth.auth()) {
        self.persistence = persistence
        self.auth = auth
        self.defaultEmailMessage = EmailTemplateSettings.standard.defaultEmailMessage

        configureAuthListener()
        bindPersistence()
    }

    deinit {
        if let authHandle { auth.removeStateDidChangeListener(authHandle) }
    }

    func resetToDefaults() {
        apply(settings: .standard)
        persistCurrentSettings()
    }

    private func configureAuthListener() {
        authHandle = auth.addStateDidChangeListener { [weak self] _, user in
            self?.loadSettings(for: user)
        }

        loadSettings(for: auth.currentUser)
    }

    private func bindPersistence() {
        $defaultEmailMessage
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.persistCurrentSettings()
            }
            .store(in: &cancellables)
    }

    private func loadSettings(for user: User?) {
        currentUserID = user?.uid
        apply(settings: .standard)

        guard let uid = user?.uid else { return }

        if let stored: EmailTemplateSettings = persistence.load(
            EmailTemplateSettings.self,
            from: EmailTemplateStorage.fileName(for: uid)
        ) {
            apply(settings: stored)
        }
    }

    private func persistCurrentSettings() {
        guard let uid = currentUserID, !isApplyingRemoteUpdate else { return }

        let settings = EmailTemplateSettings(defaultEmailMessage: defaultEmailMessage)
        persistence.save(settings, to: EmailTemplateStorage.fileName(for: uid))
    }

    private func apply(settings: EmailTemplateSettings) {
        isApplyingRemoteUpdate = true
        defaultEmailMessage = settings.defaultEmailMessage
        isApplyingRemoteUpdate = false
    }
}
