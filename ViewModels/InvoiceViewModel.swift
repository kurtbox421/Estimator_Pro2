import Foundation
import SwiftUI
import os.log
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

class InvoiceViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var previewURL: URL?
    @Published var previewError: String?
    @Published var isShowingPreview: Bool = false

    private let logger = Logger(subsystem: "com.estimatorpro.invoice", category: "InvoiceViewModel")
    private let db: Firestore
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var loggedDecodingFailures: Set<String> = []

    init(database: Firestore = Firestore.firestore()) {
        self.db = database
        configureAuthListener()
    }

    deinit {
        listener?.remove()
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    // MARK: - CRUD

    func add(_ invoice: Invoice) {
        persist(invoice, completion: nil)
    }

    func update(_ invoice: Invoice, completion: ((Error?) -> Void)? = nil) {
        persist(invoice, completion: completion)
    }

    func delete(at offsets: IndexSet) {
        let invoicesToDelete = offsets.map { invoices[$0] }
        invoices.remove(atOffsets: offsets)

        invoicesToDelete.forEach { delete($0) }
    }

    func delete(_ invoice: Invoice) {
        guard Auth.auth().currentUser != nil else { return }

        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users")
            .document(uid)
            .collection("invoices")
            .document(invoice.id.uuidString)
            .delete { [weak self] error in
                if let error {
                    self?.logger.error("Failed to delete invoice: \(error.localizedDescription)")
                }
            }
    }

    func addMaterial(to invoice: Invoice, material: Material) {
        guard let invoiceIndex = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }

        invoices[invoiceIndex].materials.append(material)
        persist(invoices[invoiceIndex])
    }

    func updateMaterial(in invoice: Invoice, at index: Int, with material: Material) {
        guard let invoiceIndex = invoices.firstIndex(where: { $0.id == invoice.id }),
              invoices[invoiceIndex].materials.indices.contains(index) else { return }

        invoices[invoiceIndex].materials[index] = material
        persist(invoices[invoiceIndex])
    }

    func removeMaterial(from invoice: Invoice, at index: Int) {
        guard let invoiceIndex = invoices.firstIndex(where: { $0.id == invoice.id }),
              invoices[invoiceIndex].materials.indices.contains(index) else { return }

        invoices[invoiceIndex].materials.remove(at: index)
        persist(invoices[invoiceIndex])
    }

    func update(_ invoice: Invoice, replacingMaterialAt index: Int, with material: Material) {
        updateMaterial(in: invoice, at: index, with: material)
    }

    func addMaterial(_ material: Material, to invoice: Invoice) {
        addMaterial(to: invoice, material: material)
    }

    func removeMaterial(at index: Int, in invoice: Invoice) {
        removeMaterial(from: invoice, at: index)
    }

    // MARK: - PDF Preview

    func generateInvoicePDF(for invoice: Invoice, client: Client?, company: CompanySettings) throws -> URL {
        try InvoicePDFRenderer.generateInvoicePDF(
            for: invoice,
            client: client,
            company: company
        )
    }

    func preview(invoice: Invoice, client: Client?, company: CompanySettings) {
        previewError = nil

        do {
            let url = try generateInvoicePDF(for: invoice, client: client, company: company)
            previewURL = url
            isShowingPreview = true
        } catch {
            previewError = error.localizedDescription
            logger.error("Failed to generate invoice PDF: \(error.localizedDescription)")
        }
    }

    // MARK: - Firestore Synchronization

    private func configureAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.attachListener(for: user)
        }

        attachListener(for: Auth.auth().currentUser)
    }

    private func attachListener(for user: User?) {
        listener?.remove()
        invoices = []

        guard let uid = user?.uid else { return }

        listener = db.collection("users")
            .document(uid)
            .collection("invoices")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    logger.error("Failed to fetch invoices: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async { self.invoices = [] }
                    return
                }

                let decoded: [Invoice] = documents.compactMap { document in
                    guard document.exists else { return nil }
                    return self.decodeInvoice(from: document)
                }

                DispatchQueue.main.async {
                    self.invoices = self.sortInvoices(decoded)
                }
            }
    }

    private func persist(_ invoice: Invoice, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            logger.error("Attempted to persist invoice without an authenticated user")
            return
        }

        var invoiceToSave = invoice
        invoiceToSave.ownerID = uid
        let previousInvoice = invoices.first(where: { $0.id == invoiceToSave.id })

        // Optimistically update local state while Firestore write completes
        if let existingIndex = invoices.firstIndex(where: { $0.id == invoiceToSave.id }) {
            invoices[existingIndex] = invoiceToSave
        } else {
            invoices.append(invoiceToSave)
        }
        invoices = sortInvoices(invoices)

        do {
            try db.collection("users")
                .document(uid)
                .collection("invoices")
                .document(invoiceToSave.id.uuidString)
                .setData(from: invoiceToSave) { [weak self] error in
                    guard let self else { return }
                    if let error {
                        DispatchQueue.main.async {
                            if let previousInvoice {
                                if let index = self.invoices.firstIndex(where: { $0.id == previousInvoice.id }) {
                                    self.invoices[index] = previousInvoice
                                } else {
                                    self.invoices.append(previousInvoice)
                                }
                            } else {
                                self.invoices.removeAll { $0.id == invoiceToSave.id }
                            }
                            self.invoices = self.sortInvoices(self.invoices)
                            self.logger.error("Failed to save invoice: \(error.localizedDescription)")
                            completion?(error)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion?(nil)
                        }
                    }
                }
        } catch {
            logger.error("Failed to save invoice: \(error.localizedDescription)")
            DispatchQueue.main.async {
                if let previousInvoice {
                    if let index = self.invoices.firstIndex(where: { $0.id == previousInvoice.id }) {
                        self.invoices[index] = previousInvoice
                    } else {
                        self.invoices.append(previousInvoice)
                    }
                } else {
                    self.invoices.removeAll { $0.id == invoiceToSave.id }
                }
                self.invoices = self.sortInvoices(self.invoices)
                completion?(error)
            }
        }
    }

    private func sortInvoices(_ invoices: [Invoice]) -> [Invoice] {
        let statusPriority: [Invoice.InvoiceStatus: Int] = [
            .overdue: 0,
            .sent: 1,
            .draft: 2
        ]

        return invoices.sorted { lhs, rhs in
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

    private func decodeInvoice(from document: DocumentSnapshot) -> Invoice? {
        let documentPath = document.reference.path
        var data = document.data() ?? [:]
        var patch: [String: Any] = [:]
        var missingFields: [String] = []

        if data["id"] == nil {
            let fallbackId = UUID(uuidString: document.documentID)?.uuidString ?? UUID().uuidString
            data["id"] = fallbackId
            patch["id"] = fallbackId
            missingFields.append("id")
        }

        if data["invoiceNumber"] == nil {
            let fallbackNumber = InvoiceNumberManager.shared.generateInvoiceNumber()
            data["invoiceNumber"] = fallbackNumber
            patch["invoiceNumber"] = fallbackNumber
            missingFields.append("invoiceNumber")
        }

        if data["title"] == nil {
            data["title"] = "Invoice"
            patch["title"] = "Invoice"
            missingFields.append("title")
        }

        if data["clientName"] == nil {
            data["clientName"] = ""
            patch["clientName"] = ""
            missingFields.append("clientName")
        }

        if data["status"] == nil {
            data["status"] = Invoice.InvoiceStatus.draft.rawValue
            patch["status"] = Invoice.InvoiceStatus.draft.rawValue
            missingFields.append("status")
        }

        do {
            let invoice = try Firestore.Decoder().decode(Invoice.self, from: data)
            if !patch.isEmpty {
                document.reference.setData(patch, merge: true)
            }
            if !missingFields.isEmpty {
                logMissingFields(missingFields, documentPath: documentPath)
            }
            return invoice
        } catch {
            logDecodingError(error, documentPath: documentPath)
            return nil
        }
    }

    private func logMissingFields(_ fields: [String], documentPath: String) {
        guard !fields.isEmpty else { return }
        let logKey = "missing:\(documentPath)"
        guard !loggedDecodingFailures.contains(logKey) else { return }
        loggedDecodingFailures.insert(logKey)
        logger.error("Missing fields in document \(documentPath): \(fields.joined(separator: \", \"))")
    }

    private func logDecodingError(_ error: Error, documentPath: String) {
        let logKey = "decode:\(documentPath)"
        guard !loggedDecodingFailures.contains(logKey) else { return }
        loggedDecodingFailures.insert(logKey)

        if case DecodingError.keyNotFound(let key, _) = error {
            logger.error("Failed to decode document \(documentPath): missing field \(key.stringValue)")
        } else {
            logger.error("Failed to decode document \(documentPath): \(error.localizedDescription)")
        }
    }
}
