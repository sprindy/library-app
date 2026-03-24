import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var author: String
    var statusRaw: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        status: BookStatus = .toRead,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.statusRaw = status.rawValue
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .toRead }
        set { statusRaw = newValue.rawValue }
    }

    func touch(at date: Date = .now) {
        updatedAt = date
    }
}
