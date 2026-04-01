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

    func testTriggerNewBookPostsNotification() {
        let commandCenter = UICommandCenter()
        let expectation = expectation(forNotification: .uiCommandCenterNewBookRequested, object: nil)

        commandCenter.triggerNewBook()

        wait(for: [expectation], timeout: 1.0)
    }

    func testTriggerFocusSearchPostsNotification() {
        let commandCenter = UICommandCenter()
        let expectation = expectation(forNotification: .uiCommandCenterFocusSearchRequested, object: nil)

        commandCenter.triggerFocusSearch()

        wait(for: [expectation], timeout: 1.0)
    }
}
