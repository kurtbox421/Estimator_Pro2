import Foundation
import Combine

final class CompanySettingsStore: ObservableObject {
    @Published var companyName: String = ""
    @Published var companyAddress: String = ""
    @Published var companyPhone: String = ""
    @Published var companyEmail: String = ""
}
