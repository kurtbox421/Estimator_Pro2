import SwiftUI
import PDFKit

struct InvoicePDFPreviewView: View {
    let url: URL

    var body: some View {
        PDFKitView(url: url)
            .ignoresSafeArea()
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true

        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
        } else {
            print("⚠️ Failed to load PDFDocument from URL:", url)
        }

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if let doc = PDFDocument(url: url) {
            uiView.document = doc
        }
    }
}
