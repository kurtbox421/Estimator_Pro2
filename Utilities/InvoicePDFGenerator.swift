import UIKit

struct InvoicePDFSnapshot {
    struct CompanyInfo {
        var name: String
        var lines: [String]
        var logo: UIImage?
    }

    struct ClientInfo {
        var title: String
        var name: String
        var lines: [String]
    }

    struct LineItem {
        var name: String
        var quantity: Double
        var unitCost: Double
        var lineTotal: Double
    }

    var title: String
    var date: Date
    var company: CompanyInfo
    var client: ClientInfo
    var materialsTitle: String
    var materials: [LineItem]
}

struct InvoicePDFGenerator {

    static func generate(snapshot: InvoicePDFSnapshot) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter

        let fileName = "\(snapshot.title)-\(UUID().uuidString).pdf"
        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(fileName)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let cg = context.cgContext

            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(pageRect)

            drawHeader(in: cg, rect: pageRect, snapshot: snapshot)
            drawCompanyAndClient(in: cg, rect: pageRect, snapshot: snapshot)
            drawMaterialsTable(in: cg, rect: pageRect, snapshot: snapshot)
        }

        return url
    }

    // MARK: - Header

    private static func drawHeader(
        in context: CGContext,
        rect: CGRect,
        snapshot: InvoicePDFSnapshot
    ) {
        let padding: CGFloat = 36

        // Logo
        if let logo = snapshot.company.logo {
            let maxSize = CGSize(width: 90, height: 90)
            let aspect = logo.size.width == 0 ? 1 : logo.size.height / logo.size.width
            let width = maxSize.width
            let height = min(width * aspect, maxSize.height)

            let logoRect = CGRect(x: padding,
                                  y: padding,
                                  width: width,
                                  height: height)
            logo.draw(in: logoRect)
        }

        // Title centered
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24)
        ]
        let title = snapshot.title
        let titleSize = title.size(withAttributes: titleAttrs)
        let titleOrigin = CGPoint(
            x: (rect.width - titleSize.width) / 2,
            y: padding + 20
        )
        title.draw(at: titleOrigin, withAttributes: titleAttrs)

        // Date on right
        let df = DateFormatter()
        df.dateStyle = .medium
        let dateString = "Date: \(df.string(from: snapshot.date))"

        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12)
        ]
        let dateSize = dateString.size(withAttributes: dateAttrs)
        let dateOrigin = CGPoint(
            x: rect.width - padding - dateSize.width,
            y: padding + 20
        )
        dateString.draw(at: dateOrigin, withAttributes: dateAttrs)
    }

    // MARK: - Company + Bill To

    private static func drawCompanyAndClient(
        in context: CGContext,
        rect: CGRect,
        snapshot: InvoicePDFSnapshot
    ) {
        let padding: CGFloat = 36
        var y = padding + 110 // below header

        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14)
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11)
        ]

        snapshot.company.name.draw(
            at: CGPoint(x: padding, y: y),
            withAttributes: nameAttrs
        )
        y += 18

        for line in snapshot.company.lines where !line.isEmpty {
            line.draw(at: CGPoint(x: padding, y: y), withAttributes: bodyAttrs)
            y += 14
        }

        // Bill To block
        y += 20
        let billTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13)
        ]
        snapshot.client.title.draw(
            at: CGPoint(x: padding, y: y),
            withAttributes: billTitleAttrs
        )
        y += 18

        snapshot.client.name.draw(
            at: CGPoint(x: padding, y: y),
            withAttributes: bodyAttrs
        )
        y += 14

        for line in snapshot.client.lines where !line.isEmpty {
            line.draw(at: CGPoint(x: padding, y: y), withAttributes: bodyAttrs)
            y += 14
        }

        // Divider line before materials
        y += 24
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: padding, y: y))
        context.addLine(to: CGPoint(x: rect.width - padding, y: y))
        context.strokePath()
    }

    // MARK: - Materials table

    private static func drawMaterialsTable(
        in context: CGContext,
        rect: CGRect,
        snapshot: InvoicePDFSnapshot
    ) {
        let padding: CGFloat = 36
        var y = padding + 220 // starting lower; adjust if needed

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14)
        ]
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11)
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11)
        ]
        let totalBoldAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11)
        ]

        // Section title
        snapshot.materialsTitle.draw(
            at: CGPoint(x: padding, y: y),
            withAttributes: titleAttrs
        )
        y += 20

        // Column headers
        let itemX = padding
        let qtyX  = rect.width * 0.55
        let unitX = rect.width * 0.70
        let lineX = rect.width * 0.83

        "Item".draw(at: CGPoint(x: itemX, y: y), withAttributes: headerAttrs)
        "Qty".draw(at: CGPoint(x: qtyX, y: y), withAttributes: headerAttrs)
        "Unit Cost".draw(at: CGPoint(x: unitX, y: y), withAttributes: headerAttrs)
        "Line Total".draw(at: CGPoint(x: lineX, y: y), withAttributes: headerAttrs)
        y += 16

        // Separator
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: padding, y: y))
        context.addLine(to: CGPoint(x: rect.width - padding, y: y))
        context.strokePath()
        y += 8

        let nf = NumberFormatter()
        nf.numberStyle = .currency

        for item in snapshot.materials {
            // Item name
            let nameRect = CGRect(x: itemX, y: y,
                                  width: rect.width * 0.5 - padding,
                                  height: 30)
            item.name.draw(
                with: nameRect,
                options: .usesLineFragmentOrigin,
                attributes: bodyAttrs,
                context: nil
            )

            let qtyString = item.quantity == floor(item.quantity)
                ? String(format: "%.0f", item.quantity)
                : String(format: "%.2f", item.quantity)

            qtyString.draw(at: CGPoint(x: qtyX, y: y), withAttributes: bodyAttrs)

            let unitString = nf.string(from: item.unitCost as NSNumber) ?? "$0.00"
            unitString.draw(at: CGPoint(x: unitX, y: y), withAttributes: bodyAttrs)

            let lineString = nf.string(from: item.lineTotal as NSNumber) ?? "$0.00"
            lineString.draw(at: CGPoint(x: lineX, y: y), withAttributes: totalBoldAttrs)

            y += 18
        }
    }
}
