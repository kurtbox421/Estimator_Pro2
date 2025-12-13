import SwiftUI
import PDFKit

struct PDFPreviewSheet: View {
    let url: URL
    @EnvironmentObject private var onboarding: OnboardingProgressStore

    var body: some View {
        PDFKitRepresentedView(url: url)
            .ignoresSafeArea()
            .onAppear {
                onboarding.hasPreviewedPDF = true
                onboarding.evaluateCompletion()
            }
    }
}

struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(url: url)
    }
}
