import Foundation
import Combine

private enum EmailTemplateStorage {
    static let fileName = "emailTemplateSettings.json"
}

struct EmailTemplateSettings: Codable {
    var defaultEmailSubject: String
    var defaultEmailBody: String

    static let standard = EmailTemplateSettings(
        defaultEmailSubject: "{{documentType}} {{invoiceNumber}}{{estimateNumber}} - {{jobName}}",
        defaultEmailBody: """
Hi {{clientName}},

Attached is your {{documentType}} for {{jobName}}.
Let me know if you have any questions.

Thanks,
{{companyName}}
"""
    )
}

final class EmailTemplateSettingsStore: ObservableObject {
    @Published var defaultEmailSubject: String
    @Published var defaultEmailBody: String

    private let persistence: PersistenceService
    private var cancellables: Set<AnyCancellable> = []

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence

        if let stored: EmailTemplateSettings = persistence.load(EmailTemplateSettings.self, from: EmailTemplateStorage.fileName) {
            defaultEmailSubject = stored.defaultEmailSubject
            defaultEmailBody = stored.defaultEmailBody
        } else {
            defaultEmailSubject = EmailTemplateSettings.standard.defaultEmailSubject
            defaultEmailBody = EmailTemplateSettings.standard.defaultEmailBody
        }

        bindPersistence()
    }

    func resetToDefaults() {
        apply(settings: .standard)
        persistence.save(EmailTemplateSettings.standard, to: EmailTemplateStorage.fileName)
    }

    private func bindPersistence() {
        Publishers.CombineLatest($defaultEmailSubject, $defaultEmailBody)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] subject, body in
                let settings = EmailTemplateSettings(defaultEmailSubject: subject, defaultEmailBody: body)
                self?.persistence.save(settings, to: EmailTemplateStorage.fileName)
            }
            .store(in: &cancellables)
    }

    private func apply(settings: EmailTemplateSettings) {
        defaultEmailSubject = settings.defaultEmailSubject
        defaultEmailBody = settings.defaultEmailBody
    }
}
