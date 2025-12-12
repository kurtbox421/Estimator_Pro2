import Foundation
import Combine

private enum EmailTemplateStorage {
    static let fileName = "emailTemplateSettings.json"
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
    private var cancellables: Set<AnyCancellable> = []

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence

        if let stored: EmailTemplateSettings = persistence.load(EmailTemplateSettings.self, from: EmailTemplateStorage.fileName) {
            defaultEmailMessage = stored.defaultEmailMessage
        } else {
            defaultEmailMessage = EmailTemplateSettings.standard.defaultEmailMessage
        }

        bindPersistence()
    }

    func resetToDefaults() {
        apply(settings: .standard)
        persistence.save(EmailTemplateSettings.standard, to: EmailTemplateStorage.fileName)
    }

    private func bindPersistence() {
        $defaultEmailMessage
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] message in
                let settings = EmailTemplateSettings(defaultEmailMessage: message)
                self?.persistence.save(settings, to: EmailTemplateStorage.fileName)
            }
            .store(in: &cancellables)
    }

    private func apply(settings: EmailTemplateSettings) {
        defaultEmailMessage = settings.defaultEmailMessage
    }
}
