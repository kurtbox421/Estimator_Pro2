import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var inventoryVM: InventoryViewModel
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var searchText: String = ""

    private var filteredSupplies: [SupplyItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return inventoryVM.supplies
        }

        return inventoryVM.supplies.filter { supply in
            supply.displayName.lowercased().contains(searchText.lowercased()) ||
            supply.unit.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    searchBar
                        .padding(.horizontal, 24)

                    LazyVStack(spacing: 12) {
                        ForEach(filteredSupplies, id: \.stableId) { supply in
                            NavigationLink {
                                SupplyDetailView(supply: supply)
                            } label: {
                                SupplyRowCard(supply: supply)
                            }
                            .buttonStyle(.plain)
                        }

                        if inventoryVM.supplies.isEmpty {
                            SupplyEmptyStateCard()
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 8)
            }
            .tint(.white)
            .allowsHitTesting(hasProAccess)

            if !hasProAccess {
                VStack(spacing: 14) {
                    Text("Inventory is a Pro feature")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)

                    Text("Upgrade to track supplies, restock history, and usage.")
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        subscriptionManager.presentPaywall()
                    } label: {
                        Text("View plans")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.9), in: Capsule())
                            .foregroundColor(.white)
                    }
                }
                .padding(24)
                .frame(maxWidth: 360)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                )
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.35).ignoresSafeArea())
            }
        }
    }
}

private extension InventoryView {
    var hasProAccess: Bool {
        subscriptionManager.accessState == .pro
    }

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.7))

            TextField("", text: $searchText, prompt: Text("Search").foregroundColor(.white.opacity(0.7)))
                .foregroundColor(.white)
                .tint(.white)
                .textInputAutocapitalization(.none)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SupplyRowCard: View {
    let supply: SupplyItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(supply.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)

                    if supply.isLowStock {
                        Text("Low")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.45))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }

                Text("On hand: \(supply.onHand, specifier: "%.2f") \(supply.unit)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            HStack(spacing: 6) {
                Text("\(supply.onHand, specifier: "%.0f")")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
}

private struct SupplyEmptyStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No supplies yet")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            Text("Tap + to add your first item.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
}

private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
}
