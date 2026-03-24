import XCTest
@testable import LibraryApp

final class CSVExporterTests: XCTestCase {
    func testExportIncludesHeaderAndEscapesFields() {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let book = Book(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "A, B",
            author: "Author \"Quoted\"",
            status: .reading,
            notes: "line1\nline2",
            createdAt: fixedDate,
            updatedAt: fixedDate
        )

        let csv = CSVExporter.export(books: [book])

        XCTAssertTrue(csv.contains("id,title,author,status,notes,createdAt,updatedAt"))
        XCTAssertTrue(csv.contains("\"A, B\""))
        XCTAssertTrue(csv.contains("\"Author \"\"Quoted\"\"\""))
        XCTAssertTrue(csv.contains("\"Reading\""))
        XCTAssertTrue(csv.contains("\"line1\nline2\""))
    }

    func testEscapeAlwaysWrapsInQuotes() {
        XCTAssertEqual(CSVExporter.escape("plain"), "\"plain\"")
        XCTAssertEqual(CSVExporter.escape("a\"b"), "\"a\"\"b\"")
    }
}
