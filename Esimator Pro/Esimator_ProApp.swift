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
    @StateObject private var jobVM = JobViewModel()
    @StateObject private var invoiceVM = InvoiceViewModel()
    @StateObject private var estimateVM = EstimateViewModel()
    @StateObject private var clientVM = ClientViewModel()
    @StateObject private var inventoryVM = InventoryViewModel()
    @StateObject private var companySettings = CompanySettingsStore()
    @StateObject private var emailTemplateSettings = EmailTemplateSettingsStore()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var session = SessionViewModel()
    @StateObject private var materialsStore = MaterialsCatalogStore()
    @StateObject private var materialIntelligence = MaterialIntelligenceStore()
    @StateObject private var onboarding = OnboardingProgressStore()
    @StateObject private var subscriptionManager = SubscriptionManager()

    @State private var showingSplash = true

    init() {
        FirebaseApp.configure()

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
                } else if session.user == nil {
                    AuthScreenView()
                } else {
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
                    .environmentObject(onboarding)
                    .environmentObject(subscriptionManager)
                }

                if showingSplash && !session.isLoading {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear(perform: dismissSplashAfterDelay)
            .environmentObject(session)
            .environmentObject(materialsStore)
            .environmentObject(materialIntelligence)
            .environmentObject(onboarding)
            .environmentObject(inventoryVM)
            .environmentObject(subscriptionManager)
            .task {
                await subscriptionManager.verifyEntitlements()
                await subscriptionManager.loadProducts()
            }
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
