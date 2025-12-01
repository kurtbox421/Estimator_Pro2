import Foundation
import Combine

private enum CompanyStorage {
    static let fileName = "companySettings.json"
}

struct CompanySettings: Codable {
    var companyName: String
    var companyAddress: String
    var companyPhone: String
    var companyEmail: String

    private enum CodingKeys: String, CodingKey {
        case companyName
        case companyAddress
        case companyPhone
        case companyEmail
    }

    static let empty = CompanySettings(companyName: "", companyAddress: "", companyPhone: "", companyEmail: "")
}

final class CompanySettingsStore: ObservableObject {
    @Published var companyName: String = ""
    @Published var companyAddress: String = ""
    @Published var companyPhone: String = ""
    @Published var companyEmail: String = ""

    var settings: CompanySettings {
        CompanySettings(
            companyName: companyName,
            companyAddress: companyAddress,
            companyPhone: companyPhone,
            companyEmail: companyEmail
        )
    }

    private let persistence: PersistenceService
    private var cancellables: Set<AnyCancellable> = []

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence
        load()
        bindSaves()
    }

    private func bindSaves() {
        Publishers.CombineLatest4($companyName, $companyAddress, $companyPhone, $companyEmail)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] name, address, phone, email in
                let settings = CompanySettings(
                    companyName: name,
                    companyAddress: address,
                    companyPhone: phone,
                    companyEmail: email
                )
                self?.persistence.save(settings, to: CompanyStorage.fileName)
            }
            .store(in: &cancellables)
    }

    private func load() {
        if let stored: CompanySettings = persistence.load(CompanySettings.self, from: CompanyStorage.fileName) {
            apply(settings: stored)
        } else {
            apply(settings: .empty)
        }
    }

    private func apply(settings: CompanySettings) {
        companyName = settings.companyName
        companyAddress = settings.companyAddress
        companyPhone = settings.companyPhone
        companyEmail = settings.companyEmail
    }
}
