import AppKit
import XCTest
@testable import LibraryApp

@MainActor
final class SearchFieldFocusTests: XCTestCase {
    func testFocusSearchFieldEditorForTypingMovesCaretToEnd() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: window.contentView?.bounds ?? .zero)
        window.contentView = container

        let field = NSSearchField(frame: NSRect(x: 20, y: 20, width: 240, height: 28))
        field.stringValue = "keyword"
        container.addSubview(field)

        window.makeKeyAndOrderFront(nil)

        focusSearchFieldEditorForTyping(field)

        guard let editor = field.currentEditor() else {
            XCTFail("Expected search field to have an active editor after focus handoff.")
            return
        }

        XCTAssertEqual(editor.selectedRange.location, (field.stringValue as NSString).length)
        XCTAssertEqual(editor.selectedRange.length, 0)
    }

    func testFocusSearchFieldEditorForTypingUsesUTF16CaretIndex() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: window.contentView?.bounds ?? .zero)
        window.contentView = container

        let field = NSSearchField(frame: NSRect(x: 20, y: 20, width: 240, height: 28))
        field.stringValue = "Book 🧪"
        container.addSubview(field)

        window.makeKeyAndOrderFront(nil)

        focusSearchFieldEditorForTyping(field)

        guard let editor = field.currentEditor() else {
            XCTFail("Expected search field to have an active editor after focus handoff.")
            return
        }

        XCTAssertEqual(editor.selectedRange.location, (field.stringValue as NSString).length)
        XCTAssertEqual(editor.selectedRange.length, 0)
    }
}
