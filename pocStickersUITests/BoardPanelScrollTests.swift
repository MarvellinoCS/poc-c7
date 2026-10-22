import XCTest

final class BoardPanelScrollTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchArguments = ["-autoBoard"]
        app.launch()
    }

    private func item(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "item-\(index)").firstMatch
    }

    private func readout(_ index: Int) -> String {
        let element = item(index)
        XCTAssertTrue(element.waitForExistence(timeout: 15), "item-\(index) not found")
        return element.value as? String ?? ""
    }

    private func scrollPanelWithSelection(_ tab: String) {
        item(0).tap()
        let opener = app.buttons[tab]
        XCTAssertTrue(opener.waitForExistence(timeout: 10), "\(tab) not found")
        opener.tap()
        let panel = app.scrollViews["panel-scroll"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10), "panel did not open")
        let before = (0..<4).map(readout)
        panel.swipeLeft()
        panel.swipeRight()
        panel.swipeLeft()
        let after = (0..<4).map(readout)
        for index in 0..<4 {
            XCTAssertEqual(after[index], before[index], "item \(index) changed while scrolling the \(tab) panel")
        }
    }

    func testScrollingTheDecoPanelDoesNotMoveTheSelectedItem() {
        scrollPanelWithSelection("board-tab-deco")
    }

    func testScrollingTheStickerPanelDoesNotMoveTheSelectedItem() {
        scrollPanelWithSelection("board-tab-sticker")
    }
}
