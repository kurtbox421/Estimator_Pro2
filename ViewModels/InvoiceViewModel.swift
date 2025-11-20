import Foundation

private let invoicesStorageKey = "EstimatorPro_Invoices"

class InvoiceViewModel: ObservableObject {
    @Published var invoices: [Invoice] = [] {
        didSet {
            saveInvoices()
        }
    }

    init() {
        if !loadInvoices() {
            invoices = [
                Invoice(
                    title: "Kitchen Remodel",
                    clientName: "Maria Sanchez",
                    materials: [
                        Material(name: "Cabinetry", quantity: 12, unitCost: 150),
                        Material(name: "Tile", quantity: 80, unitCost: 4.25)
                    ],
                    status: .draft
                ),
                Invoice(
                    title: "Patio Extension",
                    clientName: "Johnny Appleseed",
                    materials: [
                        Material(name: "Pavers", quantity: 150, unitCost: 3.5),
                        Material(name: "Sand", quantity: 20, unitCost: 15)
                    ],
                    status: .sent
                ),
                Invoice(
                    title: "Basement Finish",
                    clientName: "Harper Logistics",
                    materials: [
                        Material(name: "Drywall", quantity: 60, unitCost: 18),
                        Material(name: "Paint", quantity: 15, unitCost: 32)
                    ],
                    status: .overdue
                )
            ]
        }
    }

    // MARK: - CRUD

    func add(_ invoice: Invoice) {
        invoices.append(invoice)
    }

    func update(_ invoice: Invoice) {
        guard let index = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        invoices[index] = invoice
    }

    func delete(at offsets: IndexSet) {
        invoices.remove(atOffsets: offsets)
    }

    func delete(_ invoice: Invoice) {
        guard let index = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        invoices.remove(at: index)
    }

    func addMaterial(to invoice: Invoice, material: Material) {
        guard let invoiceIndex = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }

        invoices[invoiceIndex].materials.append(material)
    }

    func updateMaterial(in invoice: Invoice, at index: Int, with material: Material) {
        guard let invoiceIndex = invoices.firstIndex(where: { $0.id == invoice.id }),
              invoices[invoiceIndex].materials.indices.contains(index) else { return }

        invoices[invoiceIndex].materials[index] = material
    }

    func removeMaterial(from invoice: Invoice, at index: Int) {
        guard let invoiceIndex = invoices.firstIndex(where: { $0.id == invoice.id }),
              invoices[invoiceIndex].materials.indices.contains(index) else { return }

        invoices[invoiceIndex].materials.remove(at: index)
    }

    func update(_ invoice: Invoice, replacingMaterialAt index: Int, with material: Material) {
        guard let invoiceIndex = invoices.firstIndex(where: { $0.id == invoice.id }),
              invoices[invoiceIndex].materials.indices.contains(index) else { return }

        updateMaterial(in: invoice, at: index, with: material)
    }

    func addMaterial(_ material: Material, to invoice: Invoice) {
        addMaterial(to: invoice, material: material)
    }

    func removeMaterial(at index: Int, in invoice: Invoice) {
        removeMaterial(from: invoice, at: index)
    }

    // MARK: - Persistence

    private func saveInvoices() {
        do {
            let data = try JSONEncoder().encode(invoices)
            UserDefaults.standard.set(data, forKey: invoicesStorageKey)
        } catch {
            print("Failed to save invoices: \(error)")
        }
    }

    @discardableResult
    private func loadInvoices() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: invoicesStorageKey) else { return false }
        do {
            let decoded = try JSONDecoder().decode([Invoice].self, from: data)
            invoices = decoded
            return true
        } catch {
            print("Failed to load invoices: \(error)")
            return false
        }
    }
}
