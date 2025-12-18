import Foundation
import FirebaseAuth

@MainActor
final class DeleteAccountViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var showReauthenticationAlert = false
    @Published var deletionCompleted = false

    private let deletionService: AccountDeletionService

    init(deletionService: AccountDeletionService = AccountDeletionService()) {
        self.deletionService = deletionService
    }

    func deleteAccount() async {
        guard !isProcessing else { return }

        isProcessing = true
        statusMessage = nil
        errorMessage = nil
        showReauthenticationAlert = false

        do {
            try await deletionService.deleteAccount()
            statusMessage = "Your account and data have been deleted."
            deletionCompleted = true
        } catch let error as NSError where AuthErrorCode.Code(rawValue: error.code) == .requiresRecentLogin {
            errorMessage = "Please sign in again to confirm deletion."
            showReauthenticationAlert = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }
}
