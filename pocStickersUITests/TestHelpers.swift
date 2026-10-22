import XCTest

extension XCUIApplication {
    func element(_ id: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func openJournalPage() {
        buttons["tab-journal"].tap()
        let book = element("journal-book-0")
        XCTAssertTrue(book.waitForExistence(timeout: 15), "no journal book on the Journal tab")
        book.tap()
        XCTAssertTrue(element("journal-edit").waitForExistence(timeout: 10), "the book did not zoom in")
        book.tap()
        XCTAssertTrue(buttons["board-back"].waitForExistence(timeout: 10), "tapping the book did not open its page")
    }

    func goHomeFromBoard() {
        buttons["board-back"].tap()
        XCTAssertTrue(buttons["journal-back"].waitForExistence(timeout: 10), "back from the board should return to the zoomed book")
        buttons["journal-back"].tap()
        buttons["tab-home"].tap()
    }
}
