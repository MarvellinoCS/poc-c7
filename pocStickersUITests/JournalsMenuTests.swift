import XCTest

final class JournalsMenuTests: XCTestCase {
    private let app = XCUIApplication()

    private func launchFresh() {
        app.launchArguments = ["-resetBoard"]
        app.launch()
    }

    func testMenuShowsABookAndZoomsInAndOut() {
        launchFresh()
        app.buttons["tab-journal"].tap()
        XCTAssertTrue(app.element("journal-add").waitForExistence(timeout: 15), "no add-journal button on the menu")
        XCTAssertTrue(app.element("journal-book-0").exists, "no journal book on the menu")
        XCTAssertFalse(app.element("journal-edit").exists, "Edit should only show once zoomed in")

        app.element("journal-book-0").tap()
        XCTAssertTrue(app.element("journal-edit").waitForExistence(timeout: 10), "zoomed book should show Edit")
        XCTAssertTrue(app.element("journal-pages").exists, "zoomed view should have the pages button")
        XCTAssertEqual(app.element("journal-counter").label, "1 of 1")

        app.element("journal-back").tap()
        XCTAssertTrue(app.element("journal-add").waitForExistence(timeout: 10), "back should return to the menu")
        XCTAssertFalse(app.element("journal-edit").exists, "Edit should hide again")
    }

    func testAddingAJournalLetsYouEditTheCoverAndItSurvivesRelaunch() {
        launchFresh()
        app.buttons["tab-journal"].tap()
        app.element("journal-add").tap()

        let title = app.element("cover-title")
        XCTAssertTrue(title.waitForExistence(timeout: 10), "adding a journal should open the cover editor")
        title.tap()
        title.typeText(" Notes")
        app.element("cover-color-sky").tap()
        app.element("cover-icon-🌿").tap()
        app.element("cover-done").tap()

        XCTAssertTrue(app.element("journal-title").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("journal-title").label.contains("Notes"), "the new title should show on the zoomed book")
        XCTAssertEqual(app.element("journal-counter").label, "2 of 2")
        Thread.sleep(forTimeInterval: 1)

        app.terminate()
        app.launchArguments = []
        app.launch()
        app.buttons["tab-journal"].tap()
        XCTAssertTrue(app.element("journal-book-1").waitForExistence(timeout: 15), "the added journal did not survive relaunch")
        app.element("journal-book-1").tap()
        XCTAssertTrue(app.element("journal-title").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element("journal-title").label.contains("Notes"), "the edited title did not survive relaunch")
    }

    func testPagesOverviewCreatesAndListsPages() {
        launchFresh()
        app.buttons["tab-journal"].tap()
        app.element("journal-book-0").tap()
        XCTAssertTrue(app.element("journal-pages").waitForExistence(timeout: 10))
        app.element("journal-pages").tap()

        XCTAssertTrue(app.element("pages-new").waitForExistence(timeout: 10), "pages overview did not open")
        XCTAssertEqual(app.element("pages-count").label, "0 reflection pages")
        XCTAssertFalse(app.element("page-0").exists, "a fresh journal should have no pages")

        app.element("pages-new").tap()
        XCTAssertTrue(app.buttons["board-back"].waitForExistence(timeout: 10), "a new page should open the board")
        app.buttons["board-back"].tap()
        XCTAssertTrue(app.element("journal-pages").waitForExistence(timeout: 10), "board back should return to the zoomed book")
        app.element("journal-pages").tap()
        XCTAssertTrue(app.element("page-0").waitForExistence(timeout: 10), "the new page should be listed")
        XCTAssertEqual(app.element("pages-count").label, "1 reflection page")

        app.element("page-0").tap()
        XCTAssertTrue(app.buttons["board-back"].waitForExistence(timeout: 10), "tapping a page should open it")
    }

    func testDeletingAJournalRemovesIt() {
        launchFresh()
        app.buttons["tab-journal"].tap()
        app.element("journal-add").tap()
        XCTAssertTrue(app.element("cover-delete").waitForExistence(timeout: 10), "a second journal should be deletable")
        app.element("cover-delete").tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Delete journal' AND identifier != 'cover-delete'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "confirmation did not appear")
        confirm.tap()

        XCTAssertTrue(app.element("journal-add").waitForExistence(timeout: 10), "deleting should return to the menu")
        XCTAssertTrue(app.element("journal-book-0").exists)
        XCTAssertFalse(app.element("journal-book-1").exists, "the deleted journal is still there")
    }
}
