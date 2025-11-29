import Foundation

private enum InvoiceStorage {
    static let userDefaultsKey = "EstimatorPro_Invoices"
    static let fileName = "invoices.json"
}

class InvoiceViewModel: ObservableObject {
    @Published var invoices: [Invoice] = [] {
        didSet {
            saveInvoices()
        }
    }

    private let persistence: PersistenceService

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence
        loadInvoices()
    }

    // MARK: - CRUD

    func add(_ invoice: Invoice) {
        invoices.append(invoice)
        sortInvoices()
    }

    func update(_ invoice: Invoice) {
        guard let index = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        invoices[index] = invoice
        sortInvoices()
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
        sortInvoices()
    }

    func updateMaterial(in invoice: Invoice, at index: Int, with material: Material) {
        guard let invoiceIndex = invoices.firstIndex(where: { $0.id == invoice.id }),
              invoices[invoiceIndex].materials.indices.contains(index) else { return }

        invoices[invoiceIndex].materials[index] = material
        sortInvoices()
    }

    func removeMaterial(from invoice: Invoice, at index: Int) {
        guard let invoiceIndex = invoices.firstIndex(where: { $0.id == invoice.id }),
              invoices[invoiceIndex].materials.indices.contains(index) else { return }

        invoices[invoiceIndex].materials.remove(at: index)
        sortInvoices()
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
        persistence.save(invoices, to: InvoiceStorage.fileName)
    }

    private func loadInvoices() {
        if let stored: [Invoice] = persistence.load([Invoice].self, from: InvoiceStorage.fileName) {
            invoices = stored
            sortInvoices()
            return
        }

        if let migrated: [Invoice] = persistence.migrateFromUserDefaults(key: InvoiceStorage.userDefaultsKey, fileName: InvoiceStorage.fileName, as: [Invoice].self) {
            invoices = migrated
            sortInvoices()
            return
        }

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

    private func sortInvoices() {
        let statusPriority: [Invoice.InvoiceStatus: Int] = [
            .overdue: 0,
            .sent: 1,
            .draft: 2
        ]

        invoices.sort { lhs, rhs in
            let lhsPriority = statusPriority[lhs.status] ?? Int.max
            let rhsPriority = statusPriority[rhs.status] ?? Int.max

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            switch (lhs.dueDate, rhs.dueDate) {
            case let (.some(lhsDate), .some(rhsDate)) where lhsDate != rhsDate:
                return lhsDate < rhsDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }
}
