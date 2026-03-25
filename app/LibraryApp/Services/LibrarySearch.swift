import Foundation

enum LibrarySearch {
    static func filter(books: [Book], query: String) -> [Book] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return books }

        return books.filter { book in
            book.title.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil ||
            book.author.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
