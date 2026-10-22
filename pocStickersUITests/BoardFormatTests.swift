import XCTest

final class BoardFormatTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchArguments = ["-autoBoard"]
        app.launch()
    }

    private func values(_ index: Int) -> [String: Double] {
        let element = app.descendants(matching: .any).matching(identifier: "item-\(index)").firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 15), "item-\(index) not found")
        var result: [String: Double] = [:]
        for pair in (element.value as? String ?? "").split(separator: " ") {
            let parts = pair.split(separator: "=")
            if parts.count == 2, let number = Double(parts[1]) {
                result[String(parts[0])] = number
            }
        }
        return result
    }

    func testFormatBarAndCardChangeTheText() {
        let text = app.descendants(matching: .any).matching(identifier: "item-3").firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 15))
        text.doubleTap()

        let bold = app.buttons["format-bold"]
        XCTAssertTrue(bold.waitForExistence(timeout: 10), "format bar did not appear while editing")
        XCTAssertEqual(values(3)["b"], 0)
        bold.tap()
        XCTAssertEqual(values(3)["b"], 1, "bold")

        app.buttons["format-italic"].tap()
        XCTAssertEqual(values(3)["i"], 1, "italic")
        app.buttons["format-underline"].tap()
        XCTAssertEqual(values(3)["u"], 1, "underline")
        app.buttons["format-strike"].tap()
        XCTAssertEqual(values(3)["st"], 1, "strikethrough")
        app.buttons["format-align"].tap()
        XCTAssertEqual(values(3)["al"], 1, "alignment moved from leading to center")

        app.buttons["format-open"].tap()
        let title = app.buttons["style-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Format card did not open")
        title.tap()
        XCTAssertEqual(values(3)["sz"], 34, "title size")

        let bullet = app.buttons["format-list-bullet"]
        bullet.tap()
        XCTAssertEqual(values(3)["bl"], 1, "bullet list on")
        bullet.tap()
        XCTAssertEqual(values(3)["bl"], 0, "bullet list toggles off")

        app.buttons["format-close"].tap()
        XCTAssertTrue(app.buttons["format-bold"].waitForExistence(timeout: 10), "bar did not return after closing the card")
    }
}
