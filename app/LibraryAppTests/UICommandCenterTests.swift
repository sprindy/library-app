import XCTest
@testable import LibraryApp

final class UICommandCenterTests: XCTestCase {
    func testTriggerNewBookIncrementsSignal() {
        let commandCenter = UICommandCenter()
        XCTAssertEqual(commandCenter.newBookSignal, 0)

        commandCenter.triggerNewBook()
        XCTAssertEqual(commandCenter.newBookSignal, 1)

        commandCenter.triggerNewBook()
        XCTAssertEqual(commandCenter.newBookSignal, 2)
    }

    func testTriggerFocusSearchIncrementsSignal() {
        let commandCenter = UICommandCenter()
        XCTAssertEqual(commandCenter.focusSearchSignal, 0)

        commandCenter.triggerFocusSearch()
        XCTAssertEqual(commandCenter.focusSearchSignal, 1)

        commandCenter.triggerFocusSearch()
        XCTAssertEqual(commandCenter.focusSearchSignal, 2)
    }
}
