import Foundation

struct EmailTemplateContext {
    var clientName: String
    var jobName: String
    var documentType: String
    var invoiceNumber: String
    var estimateNumber: String
    var total: String
    var companyName: String
}

func renderEmailTemplate(subject: String, body: String, context: EmailTemplateContext) -> (String, String) {
    let replacements: [String: String] = [
        "{{clientName}}": context.clientName,
        "{{jobName}}": context.jobName,
        "{{documentType}}": context.documentType,
        "{{invoiceNumber}}": context.invoiceNumber,
        "{{estimateNumber}}": context.estimateNumber,
        "{{total}}": context.total,
        "{{companyName}}": context.companyName
    ]

    func replacePlaceholders(in text: String, trimmingExtraSpaces: Bool) -> String {
        var result = text
        for (token, value) in replacements {
            result = result.replacingOccurrences(of: token, with: value)
        }

        if trimmingExtraSpaces {
            while result.contains("  ") { result = result.replacingOccurrences(of: "  ", with: " ") }
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }

    let renderedSubject = replacePlaceholders(in: subject, trimmingExtraSpaces: true)
    let renderedBody = replacePlaceholders(in: body, trimmingExtraSpaces: false)

    return (renderedSubject, renderedBody)
}
