import UIKit
import PDFKit

struct InvoicePDFRenderer {
    private struct InvoiceLineItem {
        let description: String
        let amount: Double
        let productURL: URL?
    }

    static func generateInvoicePDF(for job: Job,
                                   client: Client? = nil,
                                   company: CompanySettings) throws -> URL {
        let invoiceNumber = job.id.uuidString
        let lineItems = buildLineItems(for: job)
        let total = job.total

        return try renderPDF(
            title: "Invoice",
            subtitle: job.name,
            invoiceNumber: invoiceNumber,
            client: client,
            company: company,
            lineItems: lineItems,
            total: total
        )
    }

    static func generateInvoicePDF(for invoice: Invoice,
                                   client: Client? = nil,
                                   company: CompanySettings) throws -> URL {
        let invoiceNumber = invoice.invoiceNumber
        let lineItems = invoice.materials.map { material in
            InvoiceLineItem(description: material.name, amount: material.total, productURL: material.productURL)
        }

        return try renderPDF(
            title: "Invoice",
            subtitle: invoice.title,
            invoiceNumber: invoiceNumber,
            client: client,
            company: company,
            lineItems: lineItems,
            total: invoice.amount
        )
    }

    // MARK: - Rendering

    private static func renderPDF(title: String,
                                  subtitle: String,
                                  invoiceNumber: String,
                                  client: Client?,
                                  company: CompanySettings,
                                  lineItems: [InvoiceLineItem],
                                  total: Double) throws -> URL {
        let fileName = "Invoice-\(invoiceNumber).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            var y: CGFloat = 40

            func draw(_ text: String,
                      font: UIFont,
                      x: CGFloat = 40) {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                let size = text.size(withAttributes: attributes)
                text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
                y += size.height + 6
            }

            func drawLineItem(_ item: InvoiceLineItem) {
                let descriptionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.black
                ]

                let amountAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.black
                ]

                let linkAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]

                let descriptionSize = item.description.size(withAttributes: descriptionAttributes)
                let amountString = String(format: "$%.2f", item.amount)
                let amountSize = amountString.size(withAttributes: amountAttributes)

                let startY = y

                item.description.draw(at: CGPoint(x: 40, y: y), withAttributes: descriptionAttributes)

                var nextY = y + descriptionSize.height + 4

                if let url = item.productURL {
                    let linkString = url.absoluteString
                    let attributed = NSAttributedString(string: linkString, attributes: linkAttributes)
                    let maxWidth = pageRect.width - 200
                    let linkRect = CGRect(x: 40, y: nextY, width: maxWidth, height: attributed.size().height)
                    attributed.draw(in: linkRect)
                    nextY += attributed.size().height + 4
                }

                amountString.draw(at: CGPoint(x: pageRect.width - 160, y: startY), withAttributes: amountAttributes)

                y = max(nextY, startY + amountSize.height) + 6
            }

            // Company info
            draw(company.companyName.isEmpty ? "Your Company" : company.companyName,
                 font: .boldSystemFont(ofSize: 22))
            if !company.companyAddress.isEmpty {
                draw(company.companyAddress, font: .systemFont(ofSize: 12))
            }
            if !company.companyPhone.isEmpty {
                draw("Phone: \(company.companyPhone)", font: .systemFont(ofSize: 12))
            }
            if !company.companyEmail.isEmpty {
                draw("Email: \(company.companyEmail)", font: .systemFont(ofSize: 12))
            }
            y += 10

            // Invoice header
            draw(title.uppercased(), font: .boldSystemFont(ofSize: 26))
            draw("Invoice #: \(invoiceNumber)", font: .systemFont(ofSize: 14))
            draw(subtitle, font: .systemFont(ofSize: 14))
            y += 10

            // Client info
            draw("Bill To:", font: .boldSystemFont(ofSize: 16))
            draw(client?.name ?? "Client", font: .systemFont(ofSize: 14))
            if let addr = client?.address, !addr.isEmpty {
                draw(addr, font: .systemFont(ofSize: 14))
            }
            if let phone = client?.phone, !phone.isEmpty {
                draw("Phone: \(phone)", font: .systemFont(ofSize: 14))
            }
            if let email = client?.email, !email.isEmpty {
                draw("Email: \(email)", font: .systemFont(ofSize: 14))
            }
            y += 16

            // Line items header
            draw("Description", font: .boldSystemFont(ofSize: 14))
            draw("Amount", font: .boldSystemFont(ofSize: 14),
                 x: pageRect.width - 160)

            y += 4
            context.cgContext.move(to: CGPoint(x: 40, y: y))
            context.cgContext.addLine(to: CGPoint(x: pageRect.width - 40, y: y))
            context.cgContext.strokePath()
            y += 10

            // Items
            for item in lineItems {
                drawLineItem(item)
            }

            y += 16
            context.cgContext.move(to: CGPoint(x: 40, y: y))
            context.cgContext.addLine(to: CGPoint(x: pageRect.width - 40, y: y))
            context.cgContext.strokePath()
            y += 10

            // Total
            let totalString = String(format: "$%.2f", total)
            draw("Total:", font: .boldSystemFont(ofSize: 16),
                 x: pageRect.width - 240)
            draw(totalString, font: .boldSystemFont(ofSize: 18),
                 x: pageRect.width - 160)
        }

        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }

    private static func buildLineItems(for job: Job) -> [InvoiceLineItem] {
        var items = job.materials.map { material in
            InvoiceLineItem(description: material.name, amount: material.total, productURL: material.productURL)
        }

        if job.laborHours > 0 && job.laborRate > 0 {
            let laborTotal = job.laborHours * job.laborRate
            items.append(InvoiceLineItem(description: "Labor",
                                         amount: laborTotal))
        }

        return items
    }
}
