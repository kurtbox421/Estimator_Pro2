import Foundation
import FirebaseAuth

@MainActor
final class OnboardingProgressStore: ObservableObject {
    @Published var shouldShowOnboarding: Bool = false {
        didSet { persist(shouldShowOnboarding, for: .shouldShowOnboarding) }
    }

    @Published var didCompleteOnboarding: Bool = false {
        didSet { persist(didCompleteOnboarding, for: .didCompleteOnboarding) }
    }

    @Published var companyProfileComplete: Bool = false {
        didSet { persist(companyProfileComplete, for: .companyProfileComplete) }
    }

    @Published var hasAtLeastOneClient: Bool = false {
        didSet { persist(hasAtLeastOneClient, for: .hasAtLeastOneClient) }
    }

    @Published var hasAtLeastOneEstimate: Bool = false {
        didSet { persist(hasAtLeastOneEstimate, for: .hasAtLeastOneEstimate) }
    }

    @Published var hasPreviewedPDF: Bool = false {
        didSet { persist(hasPreviewedPDF, for: .hasPreviewedPDF) }
    }

    var completedCount: Int {
        [companyProfileComplete, hasAtLeastOneClient, hasAtLeastOneEstimate, hasPreviewedPDF]
            .filter { $0 }
            .count
    }

    let totalCount: Int = 4

    var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var isAllComplete: Bool { completedCount == totalCount }

    private let userDefaults: UserDefaults
    private let auth: Auth
    private var authHandle: AuthStateDidChangeListenerHandle?

    init(userDefaults: UserDefaults = .standard, auth: Auth = Auth.auth()) {
        self.userDefaults = userDefaults
        self.auth = auth
        loadState()

        authHandle = auth.addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor in
                self?.loadState()
            }
        }
    }

    deinit {
        if let authHandle { auth.removeStateDidChangeListener(authHandle) }
    }

    func activateForNewAccount() {
        shouldShowOnboarding = true
        didCompleteOnboarding = false
    }

    func markDismissed() {
        shouldShowOnboarding = false
    }

    func evaluateCompletion() {
        if isAllComplete {
            didCompleteOnboarding = true
            shouldShowOnboarding = false
        }
    }

    // MARK: - Persistence

    private enum StorageKey: String, CaseIterable {
        case shouldShowOnboarding
        case didCompleteOnboarding
        case companyProfileComplete
        case hasAtLeastOneClient
        case hasAtLeastOneEstimate
        case hasPreviewedPDF
    }

    private func persist(_ value: Bool, for key: StorageKey) {
        guard let uid = auth.currentUser?.uid else { return }
        userDefaults.set(value, forKey: storageKey(key, uid: uid))
    }

    private func loadState() {
        guard let uid = auth.currentUser?.uid else {
            resetState()
            return
        }

        shouldShowOnboarding = userDefaults.bool(forKey: storageKey(.shouldShowOnboarding, uid: uid))
        didCompleteOnboarding = userDefaults.bool(forKey: storageKey(.didCompleteOnboarding, uid: uid))
        companyProfileComplete = userDefaults.bool(forKey: storageKey(.companyProfileComplete, uid: uid))
        hasAtLeastOneClient = userDefaults.bool(forKey: storageKey(.hasAtLeastOneClient, uid: uid))
        hasAtLeastOneEstimate = userDefaults.bool(forKey: storageKey(.hasAtLeastOneEstimate, uid: uid))
        hasPreviewedPDF = userDefaults.bool(forKey: storageKey(.hasPreviewedPDF, uid: uid))
    }

    private func resetState() {
        shouldShowOnboarding = false
        didCompleteOnboarding = false
        companyProfileComplete = false
        hasAtLeastOneClient = false
        hasAtLeastOneEstimate = false
        hasPreviewedPDF = false
    }

    private func storageKey(_ key: StorageKey, uid: String) -> String {
        "Onboarding_\(uid)_\(key.rawValue)"
    }
}
