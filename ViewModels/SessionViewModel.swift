import Foundation
import FirebaseAuth
import os.log

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = true

    private var handle: AuthStateDidChangeListenerHandle?
    private let logger = Logger(subsystem: "com.estimatorpro.session", category: "SessionViewModel")

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isLoading = false
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signOut() {
        do {
            try AuthManager.shared.signOut()
        } catch {
            logger.error("Sign out error: \(error.localizedDescription)")
        }
    }
}
