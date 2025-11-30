import Foundation
import FirebaseAuth
import Combine

final class SessionViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = true

    private var handle: AuthStateDidChangeListenerHandle?

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
            print("Sign out error: \(error)")
        }
    }
}
