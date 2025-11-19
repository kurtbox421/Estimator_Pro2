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
    @State private var showingSplash = true
    @State private var splashOpacity = 1.0

    var body: some Scene {
        WindowGroup {
            ZStack {
                NavigationStack {
                    RootView()
                }
                .environmentObject(jobVM)
                .environmentObject(invoiceVM)
                .environmentObject(clientVM)

                if showingSplash {
                    SplashScreenView()
                        .opacity(splashOpacity)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear(perform: dismissSplashIfNeeded)
        }
    }

    private func dismissSplashIfNeeded() {
        guard showingSplash else { return }
        withAnimation(.easeInOut(duration: 1.0)) {
            splashOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showingSplash = false
        }
    }
}
