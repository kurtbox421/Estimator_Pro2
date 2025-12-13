import UIKit
import PDFKit
import FirebaseAuth

struct InvoicePDFRenderer {
    private struct InvoiceLineItem {
        let description: String
        let amount: Double
        let productURL: URL?
        let detail: String?
        let isSubtotal: Bool
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
        let lineItems = buildLineItems(for: invoice)

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

        let companyLogo = CompanyLogoLoader.loadLogo()

        let data = renderer.pdfData { context in
            context.beginPage()

            let padding: CGFloat = 24
            let logoRect = drawLogo(companyLogo,
                                    in: context.cgContext,
                                    pageRect: pageRect,
                                    padding: padding)

            var y: CGFloat = padding

            func draw(_ text: String,
                      font: UIFont,
                      x: CGFloat = padding) {
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
                    .font: item.isSubtotal ? UIFont.boldSystemFont(ofSize: 13) : UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.black
                ]

                let amountAttributes: [NSAttributedString.Key: Any] = [
                    .font: item.isSubtotal ? UIFont.boldSystemFont(ofSize: 13) : UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.black
                ]

                let detailAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.darkGray
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

                item.description.draw(at: CGPoint(x: padding, y: y), withAttributes: descriptionAttributes)

                var nextY = y + descriptionSize.height + 4

                if let detail = item.detail {
                    let attributedDetail = NSAttributedString(string: detail, attributes: detailAttributes)
                    let maxWidth = pageRect.width - (padding * 2) - 160
                    let detailRect = CGRect(x: padding, y: nextY, width: maxWidth, height: attributedDetail.size().height)
                    attributedDetail.draw(in: detailRect)
                    nextY += attributedDetail.size().height + 4
                }

                if let url = item.productURL {
                    let linkString = url.absoluteString
                    let attributed = NSAttributedString(string: linkString, attributes: linkAttributes)
                    let maxWidth = pageRect.width - (padding * 2) - 160
                    let linkRect = CGRect(x: padding, y: nextY, width: maxWidth, height: attributed.size().height)
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

            if let logoRect {
                y = max(y, logoRect.maxY + 12)
            }

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
            context.cgContext.move(to: CGPoint(x: padding, y: y))
            context.cgContext.addLine(to: CGPoint(x: pageRect.width - padding, y: y))
            context.cgContext.strokePath()
            y += 10

            // Items
            for item in lineItems {
                drawLineItem(item)
            }

            y += 16
            context.cgContext.move(to: CGPoint(x: padding, y: y))
            context.cgContext.addLine(to: CGPoint(x: pageRect.width - padding, y: y))
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
            InvoiceLineItem(
                description: material.name,
                amount: material.total,
                productURL: material.productURL,
                detail: nil,
                isSubtotal: false
            )
        }

        if !job.laborLines.isEmpty {
            for labor in job.laborLines {
                let detail = String(format: "%.2f hrs × $%.2f", labor.hours, labor.rate)
                items.append(
                    InvoiceLineItem(
                        description: labor.title,
                        amount: labor.total,
                        productURL: nil,
                        detail: detail,
                        isSubtotal: false
                    )
                )
            }

            items.append(
                InvoiceLineItem(
                    description: "Labor Subtotal",
                    amount: job.laborSubtotal,
                    productURL: nil,
                    detail: nil,
                    isSubtotal: true
                )
            )
        }

        return items
    }

    private static func buildLineItems(for invoice: Invoice) -> [InvoiceLineItem] {
        var items = invoice.materials.map { material in
            InvoiceLineItem(
                description: material.name,
                amount: material.total,
                productURL: material.productURL,
                detail: nil,
                isSubtotal: false
            )
        }

        if !invoice.laborLines.isEmpty {
            for labor in invoice.laborLines {
                let detail = String(format: "%.2f hrs × $%.2f", labor.hours, labor.rate)
                items.append(
                    InvoiceLineItem(
                        description: labor.title,
                        amount: labor.total,
                        productURL: nil,
                        detail: detail,
                        isSubtotal: false
                    )
                )
            }

            items.append(
                InvoiceLineItem(
                    description: "Labor Subtotal",
                    amount: invoice.laborSubtotal,
                    productURL: nil,
                    detail: nil,
                    isSubtotal: true
                )
            )
        }

        return items
    }
}

// MARK: - Company logo support

enum CompanyLogoLoader {
    private static func logoKey(for uid: String) -> String { "brandingLogoData_\(uid)" }

    static func loadLogo() -> UIImage? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return loadLogo(for: uid)
    }

    static func loadLogo(for uid: String) -> UIImage? {
        let key = logoKey(for: uid)

        if let data = UserDefaults.standard.data(forKey: key),
           let image = UIImage(data: data) {
            return image
        }

        if let storedURL = UserDefaults.standard.url(forKey: key),
           let resolved = resolvePersistentURL(from: storedURL),
           let data = try? Data(contentsOf: resolved),
           let image = UIImage(data: data) {
            return image
        }

        if let storedPath = UserDefaults.standard.string(forKey: key),
           let url = URL(string: storedPath),
           let resolved = resolvePersistentURL(from: url),
           let data = try? Data(contentsOf: resolved),
           let image = UIImage(data: data) {
            return image
        }

        return nil
    }

    static func cacheLogoData(_ data: Data, for uid: String) {
        let key = logoKey(for: uid)
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clearCache(for uid: String) {
        let key = logoKey(for: uid)
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func resolvePersistentURL(from url: URL) -> URL? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        if url.path.contains("/tmp/") {
            let candidates: [URL?] = [
                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ]

            for base in candidates.compactMap({ $0 }) {
                let candidate = base.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return url
    }
}

// MARK: - Drawing helpers

private func drawLogo(_ logo: UIImage?,
                     in context: CGContext,
                     pageRect: CGRect,
                     padding: CGFloat) -> CGRect? {
    guard let logo else { return nil }

    let maxSize = CGSize(width: 140, height: 60)
    let boundingOrigin = CGPoint(
        x: pageRect.width - padding - maxSize.width,
        y: padding
    )

    let logoRect = aspectFitRect(for: logo.size,
                                 boundingSize: maxSize,
                                 origin: boundingOrigin)

    context.saveGState()
    logo.draw(in: logoRect)
    context.restoreGState()

    return logoRect
}

private func aspectFitRect(for imageSize: CGSize,
                           boundingSize: CGSize,
                           origin: CGPoint) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0 else {
        return CGRect(origin: origin, size: .zero)
    }

    let widthRatio = boundingSize.width / imageSize.width
    let heightRatio = boundingSize.height / imageSize.height
    let scale = min(widthRatio, heightRatio)

    let fittedSize = CGSize(width: imageSize.width * scale,
                            height: imageSize.height * scale)

    return CGRect(origin: origin,
                  size: fittedSize)
}
