import FirebaseAuth
import FirebaseFirestore
import Foundation
import os.log

@MainActor
final class SessionManager: ObservableObject {
    @Published var uid: String?
    @Published var isSignedIn: Bool = false
    @Published var isLoading: Bool = true

    private let auth: Auth
    private var handle: AuthStateDidChangeListenerHandle?
    private var listeners: [ListenerRegistration] = []
    private var resetHandlers: [UUID: () -> Void] = [:]
    private weak var subscriptionManager: SubscriptionManager?
    private let logger = Logger(subsystem: "com.estimatorpro.session", category: "SessionManager")

    init(auth: Auth = Auth.auth()) {
        self.auth = auth

        handle = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.handleAuthChange(user)
            }
        }

        handleAuthChange(auth.currentUser)
    }

    func signOut() {
        do {
            resetUserState(reason: "sign out")
            try AuthManager.shared.signOut()
        } catch {
            logger.error("Sign out error: \(error.localizedDescription)")
        }
    }

    deinit {
        if let handle {
            auth.removeStateDidChangeListener(handle)
        }
    }

    func track(_ listener: ListenerRegistration?) {
        guard let listener else { return }
        listeners.append(listener)
    }

    func registerResetHandler(_ handler: @escaping () -> Void) -> UUID {
        let token = UUID()
        resetHandlers[token] = handler
        return token
    }

    func unregisterResetHandler(_ token: UUID) {
        resetHandlers.removeValue(forKey: token)
    }

    func resetUserState(reason: String? = nil) {
        let count = listeners.count
        listeners.forEach { $0.remove() }
        listeners.removeAll()

        subscriptionManager?.clear()
        resetHandlers.values.forEach { $0() }

        let reasonText = reason ?? "unknown"
        logger.info("Reset user state. Removed \(count) listener(s). Reason: \(reasonText, privacy: .public)")
        print("[Session] resetUserState reason=\(reasonText) listenersRemoved=\(count)")
    }

    private func handleAuthChange(_ user: User?) {
        let newUID = user?.uid
        if newUID != uid {
            resetUserState(reason: "auth change")
        }

        uid = newUID
        isSignedIn = newUID != nil
        isLoading = false

        let uidValue = newUID ?? "nil"
        logger.info("Auth state updated. uid=\(uidValue, privacy: .public)")
        print("[Session] auth change uid=\(uidValue)")
    }

    func attachSubscriptionManager(_ manager: SubscriptionManager) {
        subscriptionManager = manager
    }
}
