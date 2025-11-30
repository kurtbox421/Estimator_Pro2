import SwiftUI
import PDFKit

struct InvoicePDFPreviewView: View {
    let url: URL

    var body: some View {
        PDFKitView(url: url)
            .ignoresSafeArea()
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}
