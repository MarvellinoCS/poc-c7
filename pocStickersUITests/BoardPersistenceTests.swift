import XCTest

final class BoardPersistenceTests: XCTestCase {
    private let app = XCUIApplication()

    private func item(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "item-\(index)").firstMatch
    }

    private func values(_ index: Int) -> [String: Double] {
        let element = item(index)
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

    func testBoardSurvivesRelaunch() {
        app.launchArguments = ["-resetBoard", "-seedBoard"]
        app.launch()

        XCTAssertTrue(item(1).waitForExistence(timeout: 15))
        let start = item(1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 60, dy: -50)))
        item(2).pinch(withScale: 1.6, velocity: 1)
        item(0).rotate(.pi / 3, withVelocity: 1)
        Thread.sleep(forTimeInterval: 2)

        let saved = (0..<4).map(values)
        XCTAssertNotEqual(saved[1]["x"], 0, "drag did not register before relaunch")

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["tab-journal"].waitForExistence(timeout: 15), "Journal tab not found on the Home screen after relaunch")
        app.openJournalPage()

        XCTAssertTrue(item(3).waitForExistence(timeout: 15), "text item missing after relaunch")
        XCTAssertFalse(item(4).exists, "unexpected extra item after relaunch")
        let restored = (0..<4).map(values)
        for index in 0..<4 {
            for key in ["x", "y", "s", "r"] {
                XCTAssertEqual(
                    restored[index][key] ?? .nan,
                    saved[index][key] ?? .nan,
                    accuracy: 1.5,
                    "item \(index) \(key) changed across relaunch"
                )
            }
        }
    }
}
