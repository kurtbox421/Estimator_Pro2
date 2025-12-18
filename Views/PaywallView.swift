import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String?
    @State private var showingErrorAlert = false

    var body: some View {
        PaywallSideEffectView(
            content: content,
            subscriptionManager: subscriptionManager,
            showingErrorAlert: $showingErrorAlert,
            onProductStateChange: handleProductStateChange,
            onErrorChange: handleErrorChange
        )
    }

    private var content: some View {
        PaywallScaffoldView {
            PaywallContentView(
                headerSection: headerSection,
                benefitsList: benefitsList,
                productSelection: productSelection(for: subscriptionManager.productState),
                primaryButton: primaryButton(for: subscriptionManager.productState),
                footerButtons: footerButtons,
                debugSection: debugSection
            )
        }
    }

    private var headerSection: some View {
        Text("Upgrade to Pro")
            .font(.largeTitle.bold())
            .foregroundColor(.white)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            }
        }
    }

    private func productSelection(for state: SubscriptionManager.ProductLoadState) -> some View {
        PaywallProductSelectionView(
            state: state,
            selectedProductID: $selectedProductID,
            subscriptionManager: subscriptionManager,
            orderedProducts: orderedProducts(from:)
        )
    }

    private func primaryButton(for state: SubscriptionManager.ProductLoadState) -> some View {
        PaywallPrimaryButtonView(
            state: state,
            isLoading: subscriptionManager.isLoading,
            selectedProductID: selectedProductID,
            selectedProductProvider: selectedProduct(in:),
            onUnavailable: handleUnavailablePurchase,
            purchaseAction: { product in
                Task { await subscriptionManager.purchase(product) }
            }
        )
    }

    private var footerButtons: some View {
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

            if let message = subscriptionManager.statusMessage {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(subscriptionManager.lastError == nil ? .green : .red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        #if DEBUG
        let isProText = subscriptionManager.isPro ? "true" : "false"
        Text("DEBUG: isPro = \(isProText)")
            .font(.caption)
            .foregroundColor(.white.opacity(0.6))
        #endif
    }

    private func orderedProducts(from products: [Product]) -> [Product] {
        products.sorted { lhs, rhs in
            let lhsIndex = SubscriptionManager.productIDs.firstIndex(of: lhs.id) ?? .max
            let rhsIndex = SubscriptionManager.productIDs.firstIndex(of: rhs.id) ?? .max
            return lhsIndex < rhsIndex
        }
    }

    private func selectedProduct(in products: [Product]) -> Product? {
        if let id = selectedProductID {
            return orderedProducts(from: products).first { $0.id == id }
        }
        return orderedProducts(from: products).first
    }

    private func setDefaultSelection(with products: [Product]) {
        guard selectedProductID == nil else { return }
        let ordered = orderedProducts(from: products)

        if let yearly = ordered.first(where: { $0.id == "estimator_pro_yearly" }) {
            selectedProductID = yearly.id
            return
        }

        if let first = ordered.first {
            selectedProductID = first.id
        }
    }

    private func handleProductStateChange(_ newValue: SubscriptionManager.ProductLoadState) {
        if case let .loaded(products) = newValue {
            setDefaultSelection(with: products)
        }
    }

    private func handleErrorChange(_ newValue: String?) {
        showingErrorAlert = newValue != nil
    }

    private func handleUnavailablePurchase() {
        let message = "Subscriptions are not available yet. Tap Retry."
        print("[Paywall] Subscribe tapped before products were ready. Message: \(message)")
        subscriptionManager.lastError = message
    }
}

private struct PaywallContentView<Header: View, Benefits: View, Selection: View, Primary: View, Footer: View, Debug: View>: View {
    let headerSection: Header
    let benefitsList: Benefits
    let productSelection: Selection
    let primaryButton: Primary
    let footerButtons: Footer
    let debugSection: Debug

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            benefitsList
            productSelection
            primaryButton
            footerButtons
            debugSection
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
    }
}

private struct PaywallProductSelectionView: View {
    let state: SubscriptionManager.ProductLoadState
    @Binding var selectedProductID: String?
    let subscriptionManager: SubscriptionManager
    let orderedProducts: ([Product]) -> [Product]

    var body: some View {
        VStack(spacing: 12) {
            switch state {
            case .idle:
                retryButton(message: "Products not loaded yet.")
            case .loading:
                loadingRow
            case .failed(let error):
                failureView(message: error)
            case .loaded(let products):
                ForEach(orderedProducts(products), id: \.id) { product in
                    ProductRow(
                        product: product,
                        isSelected: selectedProductID == product.id,
                        onSelect: { selectedProductID = product.id }
                    )
                    .disabled(subscriptionManager.isLoading)
                }
            }

            if let error = subscriptionManager.lastError, case .failed = state {
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

    private func failureView(message: String) -> some View {
        VStack(spacing: 8) {
            Text(message)
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
}

private struct PaywallPrimaryButtonView: View {
    let state: SubscriptionManager.ProductLoadState
    let isLoading: Bool
    let selectedProductID: String?
    let selectedProductProvider: ([Product]) -> Product?
    let onUnavailable: () -> Void
    let purchaseAction: (Product) -> Void

    var body: some View {
        Button {
            logTap()
            guard case let .loaded(products) = state else {
                onUnavailable()
                return
            }

            print("[Paywall] Loaded product IDs: \(products.map(\.id))")

            guard let product = selectedProductProvider(products) else {
                print("[Paywall] No selected product available for purchase.")
                onUnavailable()
                return
            }

            print("[Paywall] Initiating purchase for product: \(product.id)")
            purchaseAction(product)
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
        .disabled(isLoading)
    }

    private func logTap() {
        let selection = selectedProductID ?? "nil"
        let stateDescription: String
        switch state {
        case .idle: stateDescription = "idle"
        case .loading: stateDescription = "loading"
        case .loaded: stateDescription = "loaded"
        case .failed: stateDescription = "failed"
        }

        print("[Paywall] Subscribe tapped. State: \(stateDescription). Selected product ID: \(selection)")
    }
}

private struct PaywallSideEffectView<Content: View>: View {
    let content: Content
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Binding var showingErrorAlert: Bool
    let onProductStateChange: (SubscriptionManager.ProductLoadState) -> Void
    let onErrorChange: (String?) -> Void

    var body: some View {
        content
            .task { await subscriptionManager.loadProducts() }
            .onChange(of: subscriptionManager.productStateChangeToken) { _, _ in
                onProductStateChange(subscriptionManager.productState)
            }
            .onChange(of: subscriptionManager.lastError) { _, newValue in
                onErrorChange(newValue)
            }
            .alert("Purchase Error", isPresented: $showingErrorAlert, actions: {
                Button("OK", role: .cancel) { subscriptionManager.lastError = nil }
            }, message: {
                if let error = subscriptionManager.lastError {
                    Text(error)
                }
            })
    }
}

private struct PaywallScaffoldView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.95), Color(red: 0.09, green: 0.12, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                content
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ProductRow: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
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
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.white)
                    .font(.title3)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.16 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager())
}
