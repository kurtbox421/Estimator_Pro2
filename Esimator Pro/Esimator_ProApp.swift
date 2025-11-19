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

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                RootView()
            }
            .environmentObject(jobVM)
            .environmentObject(invoiceVM)
        }
    }
}
