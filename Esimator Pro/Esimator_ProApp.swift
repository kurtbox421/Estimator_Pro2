//
//  Esimator_ProApp.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI

@main
struct EstimatorProApp: App {
    @StateObject private var jobVM = JobViewModel()
    @StateObject private var invoiceVM = InvoiceViewModel()
    @StateObject private var clientVM = ClientViewModel()
    @StateObject private var companySettings = CompanySettingsStore()
    @StateObject private var settingsManager = SettingsManager()

    @State private var showingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                NavigationStack {
                    RootView()
                }
                .environmentObject(jobVM)
                .environmentObject(invoiceVM)
                .environmentObject(clientVM)
                .environmentObject(companySettings)
                .environmentObject(settingsManager)

                if showingSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear(perform: dismissSplashAfterDelay)
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
