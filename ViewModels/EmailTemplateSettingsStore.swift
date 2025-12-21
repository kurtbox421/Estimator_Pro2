import Combine
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

@MainActor
final class EmailTemplateSettingsStore: ObservableObject {
    @Published var defaultEmailMessage: String

    private let persistence: PersistenceService
    private let session: SessionManager
    private var cancellables: Set<AnyCancellable> = []
    private var resetToken: UUID?
    private var currentUserID: String?
    private var isApplyingRemoteUpdate = false

    init(persistence: PersistenceService = .shared, session: SessionManager) {
        self.persistence = persistence
        self.session = session
        self.defaultEmailMessage = EmailTemplateSettings.standard.defaultEmailMessage

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
        bindPersistence()
    }

    deinit {
        Task { @MainActor in
            cancellables.removeAll()
            if let resetToken {
                session.unregisterResetHandler(resetToken)
            }
        }
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

    private func setUser(_ uid: String?) {
        currentUserID = uid
        apply(settings: .standard)

        guard let uid else { return }

        print("[Data] EmailTemplateSettingsStore uid=\(uid) path=local:\(EmailTemplateStorage.fileName(for: uid)) action=load")
        if let stored: EmailTemplateSettings = persistence.load(
            EmailTemplateSettings.self,
            from: EmailTemplateStorage.fileName(for: uid)
        ) {
            apply(settings: stored)
        }
    }

    private func persistCurrentSettings() {
        guard let uid = currentUserID, !isApplyingRemoteUpdate else { return }

        print("[Data] EmailTemplateSettingsStore uid=\(uid) path=local:\(EmailTemplateStorage.fileName(for: uid)) action=save")
        let settings = EmailTemplateSettings(defaultEmailMessage: defaultEmailMessage)
        persistence.save(settings, to: EmailTemplateStorage.fileName(for: uid))
    }

    private func apply(settings: EmailTemplateSettings) {
        isApplyingRemoteUpdate = true
        defaultEmailMessage = settings.defaultEmailMessage
        isApplyingRemoteUpdate = false
    }

    func clear() {
        currentUserID = nil
        apply(settings: .standard)
    }
}
