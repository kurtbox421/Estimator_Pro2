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
            .sheet(isPresented: $subscriptionManager.shouldShowPaywall) {
                PaywallView()
                    .environmentObject(subscriptionManager)
            }
            .task {
                await subscriptionManager.loadProducts()
                await subscriptionManager.refreshEntitlements()
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
