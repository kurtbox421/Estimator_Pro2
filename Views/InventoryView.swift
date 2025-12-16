import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var inventoryVM: InventoryViewModel

    @State private var searchText: String = ""
    @State private var showingAddSupply = false
    @State private var editingSupply: SupplyItem?

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
        List {
            ForEach(filteredSupplies, id: \.self) { supply in
                NavigationLink {
                    SupplyDetailView(supply: supply)
                } label: {
                    SupplyRowView(supply: supply)
                }
            }

            if inventoryVM.supplies.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No supplies yet")
                        .font(.headline)
                    Text("Tap + to add your first item.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Inventory")
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingSupply = nil
                    showingAddSupply = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSupply) {
            NavigationView {
                AddEditSupplyView(supply: editingSupply) { supply in
                    inventoryVM.upsertSupply(supply)
                }
            }
        }
    }
}

private struct SupplyRowView: View {
    let supply: SupplyItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(supply.displayName)
                        .font(.headline)

                    if supply.isLowStock {
                        Text("Low")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .clipShape(Capsule())
                    }
                }

                Text("On hand: \(supply.onHand, specifier: "%.2f") \(supply.unit)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
