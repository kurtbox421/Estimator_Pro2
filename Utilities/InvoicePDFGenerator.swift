import UIKit

enum InvoicePDFError: Error {
    case failedToCreateContext
}

struct InvoicePDFGenerator {

    static func generate(
        invoice: Invoice,
        company: CompanySettingsStore
    ) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let safeTitle = invoice.title.replacingOccurrences(of: " ", with: "-")
        let fileName = "Invoice-\(safeTitle).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: url, withActions: { context in
            context.beginPage()
            let cg = context.cgContext

            drawHeader(in: cg, rect: pageRect, company: company, invoice: invoice)
            drawLineItems(in: cg, rect: pageRect, invoice: invoice)
            drawTotals(in: cg, rect: pageRect, invoice: invoice)
        })

        return url
    }

    // MARK: - Header

    private static func drawHeader(
        in context: CGContext,
        rect: CGRect,
        company: CompanySettingsStore,
        invoice: Invoice
    ) {
        let padding: CGFloat = 32
        var y = padding

        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20)
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12)
        ]

        company.companyName.draw(at: CGPoint(x: padding, y: y), withAttributes: nameAttrs)
        y += 26

        let lines: [String] = [
            company.companyAddress,
            company.companyPhone,
            company.companyEmail
        ].filter { !$0.isEmpty }

        for line in lines {
            line.draw(at: CGPoint(x: padding, y: y), withAttributes: bodyAttrs)
            y += 16
        }

        let rightX = rect.width - padding
        let paraRight = NSMutableParagraphStyle()
        paraRight.alignment = .right

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .paragraphStyle: paraRight
        ]
        let smallAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .paragraphStyle: paraRight
        ]

        let title = "INVOICE"
        title.draw(
            with: CGRect(x: rect.minX + 260, y: padding, width: rightX - 260, height: 30),
            options: .usesLineFragmentOrigin,
            attributes: titleAttrs,
            context: nil
        )

        let numberLine = "Invoice #: \(invoice.title)"
        let dateLine = "Date: \(formatted(date: invoice.dueDate ?? Date()))"

        numberLine.draw(
            with: CGRect(x: rect.minX + 260, y: padding + 32, width: rightX - 260, height: 18),
            options: .usesLineFragmentOrigin,
            attributes: smallAttrs,
            context: nil
        )

        dateLine.draw(
            with: CGRect(x: rect.minX + 260, y: padding + 48, width: rightX - 260, height: 18),
            options: .usesLineFragmentOrigin,
            attributes: smallAttrs,
            context: nil
        )
    }

    // MARK: - Line items table

    private static func drawLineItems(
        in context: CGContext,
        rect: CGRect,
        invoice: Invoice
    ) {
        let padding: CGFloat = 32
        var y = rect.midY - 60

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13)
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12)
        ]

        let descX: CGFloat = padding
        let qtyX: CGFloat = rect.width * 0.55
        let rateX: CGFloat = rect.width * 0.70
        let totalX: CGFloat = rect.width * 0.82

        "Description".draw(at: CGPoint(x: descX, y: y), withAttributes: headerAttrs)
        "Qty".draw(at: CGPoint(x: qtyX, y: y), withAttributes: headerAttrs)
        "Rate".draw(at: CGPoint(x: rateX, y: y), withAttributes: headerAttrs)
        "Total".draw(at: CGPoint(x: totalX, y: y), withAttributes: headerAttrs)

        y += 18

        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: padding, y: y))
        context.addLine(to: CGPoint(x: rect.width - padding, y: y))
        context.strokePath()

        y += 8

        for item in invoice.materials {
            item.name.draw(at: CGPoint(x: descX, y: y), withAttributes: bodyAttrs)

            let qty = String(format: "%.2f", item.quantity)
            qty.draw(at: CGPoint(x: qtyX, y: y), withAttributes: bodyAttrs)

            currency(item.unitCost).draw(at: CGPoint(x: rateX, y: y), withAttributes: bodyAttrs)
            currency(item.total).draw(at: CGPoint(x: totalX, y: y), withAttributes: bodyAttrs)

            y += 18
        }
    }

    // MARK: - Totals

    private static func drawTotals(
        in context: CGContext,
        rect: CGRect,
        invoice: Invoice
    ) {
        let padding: CGFloat = 32
        var y = rect.height - 160

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12)
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13)
        ]

        let rightX = rect.width - padding

        func drawRow(label: String, value: String) {
            label.draw(at: CGPoint(x: rightX - 160, y: y), withAttributes: labelAttrs)
            value.draw(at: CGPoint(x: rightX - 60, y: y), withAttributes: valueAttrs)
            y += 18
        }

        let subtotal = invoice.amount
        drawRow(label: "Subtotal", value: currency(subtotal))
        drawRow(label: "Tax", value: currency(0))
        drawRow(label: "Total", value: currency(subtotal))
    }

    // MARK: - Helpers

    private static func formatted(date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }

    private static func currency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f.string(from: amount as NSNumber) ?? "$0.00"
    }
}
