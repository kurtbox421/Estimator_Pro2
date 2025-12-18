import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String?
    @State private var showingErrorAlert = false

    private var orderedProducts: [Product] {
        subscriptionManager.products.sorted { lhs, rhs in
            let lhsIndex = SubscriptionManager.productIDs.firstIndex(of: lhs.id) ?? .max
            let rhsIndex = SubscriptionManager.productIDs.firstIndex(of: rhs.id) ?? .max
            return lhsIndex < rhsIndex
        }
    }

    private var selectedProduct: Product? {
        if let id = selectedProductID {
            return orderedProducts.first { $0.id == id }
        }
        return orderedProducts.first
    }

    private func setDefaultSelection() {
        guard selectedProductID == nil else { return }

        if let yearly = orderedProducts.first(where: { $0.id == "estimator_pro_yearly" }) {
            selectedProductID = yearly.id
            return
        }

        if let first = orderedProducts.first {
            selectedProductID = first.id
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color(red: 0.09, green: 0.12, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Upgrade to Pro")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                benefitsList

                productSelection

                primaryButton

                VStack(spacing: 10) {
                    Button {
                        Task { await subscriptionManager.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Button("Not now") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }

                #if DEBUG
                Text("DEBUG: isPro = \(subscriptionManager.isPro ? "true" : "false")")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                #endif
            }
            .padding(24)
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
        }
        .task { await subscriptionManager.loadProducts() }
        .onChange(of: subscriptionManager.productState) { _, newValue in
            if case .loaded = newValue {
                setDefaultSelection()
            }
        }
        .onChange(of: subscriptionManager.lastError) { _, newValue in
            showingErrorAlert = newValue != nil
        }
        .alert("Purchase Error", isPresented: $showingErrorAlert, actions: {
            Button("OK", role: .cancel) { subscriptionManager.lastError = nil }
        }, message: {
            if let error = subscriptionManager.lastError {
                Text(error)
            }
        })
    }

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach([
                "Unlimited saved estimates & invoices",
                "Saved clients & custom materials",
                "Inventory tracking",
                "Branded PDFs"
            ], id: \.self) { benefit in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(benefit)
                        .foregroundColor(.white)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var productSelection: some View {
        VStack(spacing: 12) {
            switch subscriptionManager.productState {
            case .idle:
                retryButton(message: "Products not loaded yet.")
            case .loading:
                loadingRow
            case .failed(let error):
                VStack(spacing: 8) {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    retryButton()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            case .loaded:
                ForEach(orderedProducts, id: \.id) { product in
                    Button {
                        selectedProductID = product.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.displayName)
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                Text(product.displayPrice)
                                    .foregroundColor(.white.opacity(0.85))
                                    .font(.subheadline)
                            }
                            Spacer()
                            if product.id == "estimator_pro_yearly" {
                                Text("Save 2 months")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.25), in: Capsule())
                                    .foregroundColor(.green)
                            }
                            Image(systemName: selectedProduct?.id == product.id ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(.white)
                                .font(.title3)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(selectedProduct?.id == product.id ? 0.16 : 0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(subscriptionManager.isLoading)
                }
            }

            if let error = subscriptionManager.lastError, case .failed = subscriptionManager.productState {
                Text(error)
                    .font(.caption2.monospaced())
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.top, 4)
            }
        }
    }

    private var loadingRow: some View {
        HStack {
            ProgressView()
                .tint(.white)
            Text("Loading products…")
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func retryButton(message: String? = nil) -> some View {
        VStack(spacing: 8) {
            if let message {
                Text(message)
                    .foregroundColor(.white.opacity(0.8))
            }
            Button {
                Task { await subscriptionManager.loadProducts() }
            } label: {
                Text("Retry")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.4), in: Capsule())
            }
        }
    }

    private var primaryButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task { await subscriptionManager.purchase(product) }
        } label: {
            Text("Subscribe")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(18)
        }
        .disabled(
            subscriptionManager.isLoading ||
            subscriptionManager.products.isEmpty ||
            selectedProduct == nil
        )
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager())
}
