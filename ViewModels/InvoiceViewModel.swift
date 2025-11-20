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
                Invoice(title: "Kitchen Remodel", clientName: "Maria Sanchez", amount: 12_450, status: .draft),
                Invoice(title: "Patio Extension", clientName: "Johnny Appleseed", amount: 8_800, status: .sent),
                Invoice(title: "Basement Finish", clientName: "Harper Logistics", amount: 18_750, status: .overdue)
            ]
        }
    }

    // MARK: - CRUD

    @discardableResult
    func createInvoice(from job: Job, clientName: String) -> Invoice {
        let invoice = Invoice(from: job, clientName: clientName)
        invoices.append(invoice)
        saveInvoices()
        return invoice
    }

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
