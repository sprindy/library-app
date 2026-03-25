import Foundation

enum CSVExporter {
    private static let headers = ["id", "title", "author", "status", "notes", "createdAt", "updatedAt"]

    static func export(books: [Book]) -> String {
        var lines = [headers.joined(separator: ",")]
        let isoFormatter = ISO8601DateFormatter()

        for book in books {
            let row = [
                escape(book.id.uuidString),
                escape(book.title),
                escape(book.author),
                escape(book.status.displayName),
                escape(book.notes ?? ""),
                escape(isoFormatter.string(from: book.createdAt)),
                escape(isoFormatter.string(from: book.updatedAt))
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    static func escape(_ value: String) -> String {
        let escapedQuotes = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedQuotes)\""
    }
}
