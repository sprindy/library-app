import XCTest
@testable import LibraryApp

final class LibrarySearchTests: XCTestCase {
    func testFilterMatchesTitleAndAuthorCaseInsensitive() {
        let books = [
            Book(title: "The Pragmatic Programmer", author: "Andy Hunt"),
            Book(title: "Clean Code", author: "Robert C. Martin"),
            Book(title: "Refactoring", author: "Martin Fowler")
        ]

        let byTitle = LibrarySearch.filter(books: books, query: "pragmatic")
        XCTAssertEqual(byTitle.map(\.title), ["The Pragmatic Programmer"])

        let byAuthor = LibrarySearch.filter(books: books, query: "MARTIN")
        XCTAssertEqual(byAuthor.count, 2)
        XCTAssertEqual(byAuthor.map(\.title), ["Clean Code", "Refactoring"])
    }

    func testFilterReturnsAllForEmptyQuery() {
        let books = [
            Book(title: "Dune", author: "Frank Herbert"),
            Book(title: "1984", author: "George Orwell")
        ]

        let result = LibrarySearch.filter(books: books, query: "   ")
        XCTAssertEqual(result.count, 2)
    }
}
