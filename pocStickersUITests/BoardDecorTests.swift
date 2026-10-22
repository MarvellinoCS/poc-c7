import XCTest

final class BoardDecorTests: XCTestCase {
    private let app = XCUIApplication()

    private func elements(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func openDrawTab() {
        elements("board-bar").swipeLeft()
        elements("board-tab-draw").tap()
    }

    private var itemCount: Int {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'item-'")).count
    }

    private func readout(_ index: Int) -> String {
        let element = elements("item-\(index)")
        XCTAssertTrue(element.waitForExistence(timeout: 15), "item-\(index) not found")
        return (element.value as? String ?? "")
            .replacingOccurrences(of: " sel=0", with: "")
            .replacingOccurrences(of: " sel=1", with: "")
    }

    func testBarHasSevenTabsInTheDesignedOrder() {
        app.launchArguments = ["-autoBoard"]
        app.launch()
        let order = ["paper", "text", "image", "sticker", "deco", "washi", "draw"]
        var lastX = -Double.infinity
        for name in order {
            let tab = elements("board-tab-\(name)")
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "tab \(name) missing")
            XCTAssertGreaterThan(Double(tab.frame.minX), lastX, "tab \(name) is out of order")
            lastX = Double(tab.frame.minX)
        }
    }

    func testWashiTapePlacesAnItem() {
        app.launchArguments = ["-autoBoard"]
        app.launch()
        let before = itemCount
        elements("board-tab-washi").tap()
        let tape = elements("tape-0")
        XCTAssertTrue(tape.waitForExistence(timeout: 10), "tape swatches did not appear")
        tape.tap()
        XCTAssertEqual(itemCount, before + 1, "tapping a tape should place exactly one item")
        tape.tap()
        XCTAssertEqual(itemCount, before + 2, "tapping again should place another strip")
    }

    func testDrawingAddsAStrokeWithoutMovingTheSelectedItem() {
        app.launchArguments = ["-autoBoard"]
        app.launch()
        XCTAssertTrue(elements("item-0").waitForExistence(timeout: 15))
        elements("item-0").tap()
        let before = (0..<4).map(readout)
        let count = itemCount

        openDrawTab()
        let layer = elements("draw-layer")
        XCTAssertTrue(layer.waitForExistence(timeout: 10), "drawing layer did not appear")
        let start = layer.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25))
        start.press(forDuration: 0.05, thenDragTo: layer.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.45)))

        XCTAssertEqual(itemCount, count + 1, "one drawn stroke should add one item")
        for index in 0..<4 {
            XCTAssertEqual(readout(index), before[index], "item \(index) changed while drawing")
        }
        elements("draw-done").tap()
        XCTAssertFalse(elements("draw-layer").waitForExistence(timeout: 3), "drawing layer should close on Done")
    }

    func testTapeAndStrokeSurviveRelaunch() {
        app.launchArguments = ["-resetBoard"]
        app.launch()
        app.openJournalPage()
        elements("board-tab-washi").tap()
        elements("tape-0").tap()
        openDrawTab()
        let layer = elements("draw-layer")
        XCTAssertTrue(layer.waitForExistence(timeout: 10))
        layer.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
            .press(forDuration: 0.05, thenDragTo: layer.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
        XCTAssertEqual(itemCount, 2, "expected one tape and one stroke")
        Thread.sleep(forTimeInterval: 2)

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(elements("tab-journal").waitForExistence(timeout: 15))
        app.openJournalPage()
        XCTAssertTrue(elements("item-1").waitForExistence(timeout: 15), "items did not survive relaunch")
        XCTAssertEqual(itemCount, 2, "wrong number of items after relaunch")
    }
}
