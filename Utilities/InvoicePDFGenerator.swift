import UIKit

struct InvoicePDFGenerator {

    static func generate(
        invoice: Invoice,
        company: CompanySettingsStore
    ) throws -> URL {

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter

        let fileName = "Invoice-\(invoice.number).pdf"
        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(fileName)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: url) { context in
            context.beginPage()

            let cg = context.cgContext

            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(pageRect)

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.black
            ]
            "INVOICE PREVIEW".draw(
                at: CGPoint(x: 72, y: 72),
                withAttributes: titleAttrs
            )

            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]

            let companyName = company.companyName.isEmpty
                ? "Company name not set"
                : company.companyName

            companyName.draw(
                at: CGPoint(x: 72, y: 120),
                withAttributes: bodyAttrs
            )

            let info = """
            Invoice #: \(invoice.number)
            Total: \(currency(invoice.total))
            """
            info.draw(
                with: CGRect(x: 72, y: 160, width: pageRect.width - 144, height: 200),
                options: .usesLineFragmentOrigin,
                attributes: bodyAttrs,
                context: nil
            )
        }

        return url
    }

    private static func currency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f.string(from: amount as NSNumber) ?? "$0.00"
    }
}
