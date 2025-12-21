import Foundation
import Combine

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
    private let session: SessionManager
    private var cancellables: Set<AnyCancellable> = []
    private var resetToken: UUID?

    init(userDefaults: UserDefaults = .standard, session: SessionManager) {
        self.userDefaults = userDefaults
        self.session = session
        loadState()

        resetToken = session.registerResetHandler { [weak self] in
            self?.resetState()
        }
        session.$uid
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadState()
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.removeAll()
        if let resetToken {
            let session = session
            Task { @MainActor in
                session.unregisterResetHandler(resetToken)
            }
        }
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
        guard let uid = session.uid else { return }
        print("[Data] OnboardingProgressStore uid=\(uid) path=local:Onboarding action=save \(key.rawValue)")
        userDefaults.set(value, forKey: storageKey(key, uid: uid))
    }

    private func loadState() {
        guard let uid = session.uid else {
            resetState()
            return
        }

        print("[Data] OnboardingProgressStore uid=\(uid) path=local:Onboarding action=load")
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
