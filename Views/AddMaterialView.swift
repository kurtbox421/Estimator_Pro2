//
//  AddMaterialView.swift
//  Esimator Pro
//
//  Created by Curtis Bollinger on 11/18/25.
//

import SwiftUI
import FirebaseAuth

struct AddMaterialView: View {
    enum Mode {
        case add(job: Job)
        case edit(job: Job, index: Int)
        case addToInvoice(invoice: Invoice)
        case editInInvoice(invoice: Invoice, index: Int)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    let mode: Mode
    @ObservedObject var jobVM: JobViewModel
    @ObservedObject var invoiceVM: InvoiceViewModel

    @State private var name: String = ""
    @State private var quantityText: String = ""
    @State private var unitCostText: String = ""
    @State private var productURLText: String = ""

    private let existingMaterialID: UUID?

    init(mode: Mode, jobVM: JobViewModel, invoiceVM: InvoiceViewModel) {
        self.mode = mode
        self.jobVM = jobVM
        self.invoiceVM = invoiceVM

        switch mode {
        case .add:
            existingMaterialID = nil
        case .edit(let job, let index):
            if job.materials.indices.contains(index) {
                let material = job.materials[index]
                existingMaterialID = material.id
                _name = State(initialValue: material.name)
                _quantityText = State(initialValue: String(material.quantity))
                _unitCostText = State(initialValue: String(material.unitCost))
                _productURLText = State(initialValue: material.productURL?.absoluteString ?? "")
            } else {
                existingMaterialID = nil
            }
        case .addToInvoice:
            existingMaterialID = nil
        case .editInInvoice(let invoice, let index):
            if invoice.materials.indices.contains(index) {
                let material = invoice.materials[index]
                existingMaterialID = material.id
                _name = State(initialValue: material.name)
                _quantityText = State(initialValue: String(material.quantity))
                _unitCostText = State(initialValue: String(material.unitCost))
                _productURLText = State(initialValue: material.productURL?.absoluteString ?? "")
            } else {
                existingMaterialID = nil
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Material")) {
                    TextField("Name", text: $name)
                }

                Section(header: Text("Details")) {
                    TextField("Quantity", text: $quantityText)
                        .keyboardType(.decimalPad)
                    TextField("Unit cost", text: $unitCostText)
                        .keyboardType(.decimalPad)
                    TextField("Product URL (optional)", text: $productURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: name, initial: false) { _, _ in
                applyCommonMaterialPriceIfNeeded()
            }
            .onChange(of: quantityText, initial: false) { _, _ in
                applyCommonMaterialPriceIfNeeded()
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parseDouble(quantityText) != nil &&
        parseDouble(unitCostText) != nil &&
        isValidProductURLText(productURLText)
    }

    private func save() {
        guard let q = parseDouble(quantityText),
              let u = parseDouble(unitCostText)
        else { return }

        let quantity = debugCheckNaN(q, label: "material quantity")
        let unitCost = debugCheckNaN(u, label: "material unit cost")

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        guard let uid = Auth.auth().currentUser?.uid else { return }

        let productURL = parsedURL(from: productURLText)

        let material = Material(
            id: existingMaterialID ?? UUID(),
            ownerID: uid,
            name: trimmedName,
            quantity: quantity,
            unitCost: unitCost,
            productURL: productURL
        )

        switch mode {
        case .add(let job):
            jobVM.addMaterial(material, to: job)
        case .edit(let job, let index):
            jobVM.update(job, replacingMaterialAt: index, with: material)
        case .addToInvoice(let invoice):
            invoiceVM.addMaterial(to: invoice, material: material)
        case .editInInvoice(let invoice, let index):
            invoiceVM.updateMaterial(in: invoice, at: index, with: material)
        }

        dismiss()
    }

    private var modeTitle: String {
        switch mode {
        case .add, .addToInvoice: return "Add Material"
        case .edit, .editInInvoice: return "Edit Material"
        }
    }

    private func applyCommonMaterialPriceIfNeeded() {
        guard let price = settingsManager.commonMaterialPrice(for: name),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        if unitCostText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            unitCostText = String(format: "%.2f", price)
        }
    }

    private func isValidProductURLText(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        return parsedURL(from: text) != nil
    }

    private func parsedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty else { return nil }
        return url
    }
}

extension AddMaterialView.Mode: Identifiable {
    var id: String {
        switch self {
        case .add(let job):
            return "add-job-\(job.id)"
        case .edit(let job, let index):
            return "edit-job-\(job.id)-\(index)"
        case .addToInvoice(let invoice):
            return "add-invoice-\(invoice.id)"
        case .editInInvoice(let invoice, let index):
            return "edit-invoice-\(invoice.id)-\(index)"
        }
    }
}

