import Foundation

enum PDFTempWriter {
    enum WriterError: Error {
        case missingSource
    }

    static func makeTempPDF(from url: URL? = nil, data: Data? = nil, fileName: String) throws -> URL {
        let sanitizedName = sanitizedFileName(fileName)
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(sanitizedName)

        let pdfURL: URL
        if destinationURL.pathExtension.lowercased() == "pdf" {
            pdfURL = destinationURL
        } else {
            pdfURL = destinationURL.appendingPathExtension("pdf")
        }

        if FileManager.default.fileExists(atPath: pdfURL.path) {
            try? FileManager.default.removeItem(at: pdfURL)
        }

        if let data {
            try data.write(to: pdfURL, options: .atomic)
            return pdfURL
        }

        if let sourceURL = url {
            let pdfData = try Data(contentsOf: sourceURL)
            try pdfData.write(to: pdfURL, options: .atomic)
            return pdfURL
        }

        throw WriterError.missingSource
    }

    private static func sanitizedFileName(_ rawName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let components = rawName.components(separatedBy: invalidCharacters)
        let sanitized = components.joined(separator: "-")
        if sanitized.isEmpty { return "Document" }
        return sanitized
    }
}
