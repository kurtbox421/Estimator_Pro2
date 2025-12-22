//
//  Esimator_ProApp.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI
import FirebaseCore

@main
struct EstimatorProApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session: SessionManager
    @StateObject private var onboarding: OnboardingProgressStore
    @StateObject private var subscriptionManager: SubscriptionManager

    @State private var showingSplash = true

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        let session = SessionManager()
        _session = StateObject(wrappedValue: session)
        _onboarding = StateObject(wrappedValue: OnboardingProgressStore(session: session))
        _subscriptionManager = StateObject(wrappedValue: SubscriptionManager(session: session))
#if DEBUG
        let bundleID = Bundle.main.bundleIdentifier ?? "(missing bundle identifier)"
        let schemeName = ProcessInfo.processInfo.environment["XCODE_SCHEME"] ?? "(unknown scheme)"
        let storeKitConfigName = "EstimatorPro"
        let storeKitResourceURL = Bundle.main.url(forResource: storeKitConfigName, withExtension: "storekit")?.path ?? "(not found in bundle)"
        let storeKitEnvPath = ProcessInfo.processInfo.environment["SIMULATOR_MAIN_STOREKIT_CONFIG"] ??
            ProcessInfo.processInfo.environment["STOREKIT_CONFIG"] ??
            "(environment path not set)"

        print("[Launch] Bundle ID: \(bundleID)")
        print("[Launch] Scheme: \(schemeName)")
        print("[Launch] StoreKit resource path: \(storeKitResourceURL)")
        print("[Launch] StoreKit config env: \(storeKitEnvPath)")
#endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if session.isLoading {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                } else if session.isSignedIn, let uid = session.uid {
                    SessionScopedRoot(uid: uid, session: session)
                        .id(uid)
                } else {
                    AuthScreenView()
                }

                if showingSplash && !session.isLoading {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear(perform: dismissSplashAfterDelay)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await subscriptionManager.refreshEntitlements() }
            }
            .environmentObject(session)
            .environmentObject(onboarding)
            .environmentObject(subscriptionManager)
        }
    }

    private func dismissSplashAfterDelay() {
        guard showingSplash else { return }

        // Keep splash fully visible for 2 seconds, then fade out over 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 1.0)) {
                showingSplash = false
            }
        }
    }
}

private struct SessionScopedRoot: View {
    let uid: String
    let session: SessionManager

    @StateObject private var jobVM: JobViewModel
    @StateObject private var invoiceVM: InvoiceViewModel
    @StateObject private var estimateVM: EstimateViewModel
    @StateObject private var clientVM: ClientViewModel
    @StateObject private var inventoryVM: InventoryViewModel
    @StateObject private var companySettings: CompanySettingsStore
    @StateObject private var emailTemplateSettings: EmailTemplateSettingsStore
    @StateObject private var settingsManager: SettingsManager
    @StateObject private var materialsStore: MaterialsCatalogStore
    @StateObject private var materialIntelligence: MaterialIntelligenceStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    init(uid: String, session: SessionManager) {
        self.uid = uid
        self.session = session
        _jobVM = StateObject(wrappedValue: JobViewModel(session: session))
        _invoiceVM = StateObject(wrappedValue: InvoiceViewModel(session: session))
        _estimateVM = StateObject(wrappedValue: EstimateViewModel())
        _clientVM = StateObject(wrappedValue: ClientViewModel(session: session))
        _inventoryVM = StateObject(wrappedValue: InventoryViewModel(session: session))
        _companySettings = StateObject(wrappedValue: CompanySettingsStore(session: session))
        _emailTemplateSettings = StateObject(wrappedValue: EmailTemplateSettingsStore(session: session))
        _settingsManager = StateObject(wrappedValue: SettingsManager(session: session))
        _materialsStore = StateObject(wrappedValue: MaterialsCatalogStore(session: session))
        _materialIntelligence = StateObject(wrappedValue: MaterialIntelligenceStore(session: session))
    }

    var body: some View {
        NavigationStack {
            RootView()
        }
        .environmentObject(jobVM)
        .environmentObject(invoiceVM)
        .environmentObject(estimateVM)
        .environmentObject(clientVM)
        .environmentObject(inventoryVM)
        .environmentObject(companySettings)
        .environmentObject(emailTemplateSettings)
        .environmentObject(settingsManager)
        .environmentObject(materialsStore)
        .environmentObject(materialIntelligence)
        .task {
            await subscriptionManager.refreshEntitlements()
            await subscriptionManager.loadProducts()
        }
    }
}
