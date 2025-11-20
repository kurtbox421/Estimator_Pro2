import Foundation

enum Formatters {
    static let invoiceDueDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()
}

extension Double {
    var currencyFormatted: String {
        let number = NSNumber(value: self)
        return NumberFormatter.currency.string(from: number)
            ?? String(format: "$%.2f", self)
    }
}
