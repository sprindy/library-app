import SwiftData
import XCTest
@testable import LibraryApp

@MainActor
final class PersistenceTests: XCTestCase {
    func testInsertAndFetchBookInMemoryContainer() throws {
        let container = try ModelContainer(
            for: Book.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let book = Book(title: "Dune", author: "Frank Herbert", status: .toRead)
        context.insert(book)
        try context.save()

        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Dune")
        XCTAssertEqual(fetched.first?.author, "Frank Herbert")
    }

    func testStatusUpdatePersistsInMemoryContainer() throws {
        let container = try ModelContainer(
            for: Book.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let book = Book(title: "The Hobbit", author: "J. R. R. Tolkien", status: .toRead)
        context.insert(book)
        try context.save()

        book.status = .finished
        book.touch(at: Date(timeIntervalSince1970: 1_700_000_000))
        try context.save()

        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.first?.status, .finished)
    }
}
