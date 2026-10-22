import XCTest

final class BoardTwoFingerTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchArguments = ["-autoBoard", "-overlap"]
        app.launch()
    }

    private func item(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "item-\(index)").firstMatch
    }

    private func value(_ index: Int, _ key: String) -> Double {
        let element = item(index)
        XCTAssertTrue(element.waitForExistence(timeout: 15), "item-\(index) not found")
        for pair in (element.value as? String ?? "").split(separator: " ") {
            let parts = pair.split(separator: "=")
            if parts.count == 2, parts[0] == key, let number = Double(parts[1]) {
                return number
            }
        }
        return .nan
    }

    private func selectTheStickerByItsTopEdge() {
        item(0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
        XCTAssertEqual(value(0, "sel"), 1, "the sticker should be selected before the two-finger gesture")
    }

    func testRotatingKeepsTheSelectedItemEvenWhenAnotherSitsOnTopOfIt() {
        XCTAssertTrue(item(4).waitForExistence(timeout: 15), "overlapping item missing")
        selectTheStickerByItsTopEdge()
        item(0).rotate(.pi / 3, withVelocity: 1)
        XCTAssertEqual(value(0, "r"), 60, accuracy: 25, "the selected sticker should rotate")
        XCTAssertEqual(value(4, "r"), 0, accuracy: 3, "the item lying on top must not rotate")
        XCTAssertEqual(value(0, "sel"), 1, "selection should stay on the sticker")
        XCTAssertEqual(value(4, "sel"), 0, "selection must not jump to the item on top")
    }

    func testPinchingKeepsTheSelectedItemEvenWhenAnotherSitsOnTopOfIt() {
        XCTAssertTrue(item(4).waitForExistence(timeout: 15), "overlapping item missing")
        selectTheStickerByItsTopEdge()
        item(0).pinch(withScale: 1.6, velocity: 1)
        XCTAssertEqual(value(0, "s"), 1.6, accuracy: 0.4, "the selected sticker should scale")
        XCTAssertEqual(value(4, "s"), 1.0, accuracy: 0.05, "the item lying on top must not scale")
        XCTAssertEqual(value(0, "sel"), 1, "selection should stay on the sticker")
    }
}
