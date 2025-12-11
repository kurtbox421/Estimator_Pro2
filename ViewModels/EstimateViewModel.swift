import Foundation
import SwiftUI
import os.log

/// Handles generation and preview management for estimate PDFs.
@MainActor
class EstimateViewModel: ObservableObject {
    @Published var previewURL: URL?
    @Published var previewError: String?
    @Published var isShowingPreview = false

    private let logger = Logger(subsystem: "com.estimatorpro.estimate", category: "EstimateViewModel")

    func generatePDF(for estimate: Job, client: Client?, company: CompanySettings) throws -> URL {
        try InvoicePDFRenderer.generateInvoicePDF(
            for: estimate,
            client: client,
            company: company
        )
    }

    func preview(estimate: Job, client: Client?, company: CompanySettings) {
        previewError = nil

        do {
            let url = try generatePDF(for: estimate, client: client, company: company)
            previewURL = url
            isShowingPreview = true
        } catch {
            previewError = error.localizedDescription
            logger.error("Failed to generate estimate PDF: \(error.localizedDescription)")
        }
    }
}
