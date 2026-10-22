import XCTest

final class BoardTextMoveTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchArguments = ["-autoBoard"]
        app.launch()
    }

    private func item(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "item-\(index)").firstMatch
    }

    private func position(_ index: Int) -> (x: Double, y: Double) {
        let element = item(index)
        XCTAssertTrue(element.waitForExistence(timeout: 15), "item-\(index) not found")
        var x = Double.nan, y = Double.nan
        for pair in (element.value as? String ?? "").split(separator: " ") {
            let parts = pair.split(separator: "=")
            if parts.count == 2, let number = Double(parts[1]) {
                if parts[0] == "x" { x = number }
                if parts[0] == "y" { y = number }
            }
        }
        return (x, y)
    }

    private func addSecondText() {
        let tab = app.buttons["board-tab-text"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Text tab not found")
        tab.tap()
        XCTAssertTrue(item(4).waitForExistence(timeout: 10), "second text item missing")
    }

    private func drag(_ index: Int, dx: CGFloat, dy: CGFloat) {
        let start = item(index).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)))
    }

    func testDraggingTheNewTextMovesOnlyTheNewText() {
        addSecondText()
        let older = position(3)
        let newer = position(4)
        drag(4, dx: 40, dy: 30)
        XCTAssertEqual(position(3).x, older.x, accuracy: 2, "older text moved in x")
        XCTAssertEqual(position(3).y, older.y, accuracy: 2, "older text moved in y")
        XCTAssertEqual(position(4).x - newer.x, 40, accuracy: 12, "newer text did not follow in x")
        XCTAssertEqual(position(4).y - newer.y, 30, accuracy: 12, "newer text did not follow in y")
    }

    func testDraggingTheOlderTextMovesOnlyTheOlderText() {
        addSecondText()
        let older = position(3)
        let newer = position(4)
        drag(3, dx: -40, dy: 30)
        XCTAssertEqual(position(4).x, newer.x, accuracy: 2, "newer (selected) text moved in x")
        XCTAssertEqual(position(4).y, newer.y, accuracy: 2, "newer (selected) text moved in y")
        XCTAssertEqual(position(3).x - older.x, -40, accuracy: 12, "older text did not follow in x")
        XCTAssertEqual(position(3).y - older.y, 30, accuracy: 12, "older text did not follow in y")
    }

    private func snapshot() -> [(x: Double, y: Double)] {
        (0..<5).map(position)
    }

    func testDraggingATextWhileEditingMovesThatText() {
        addSecondText()
        item(3).doubleTap()
        XCTAssertTrue(app.buttons["format-bold"].waitForExistence(timeout: 10), "editing did not start")
        Thread.sleep(forTimeInterval: 1)
        let before = snapshot()
        drag(3, dx: 0, dy: -60)
        let after = snapshot()
        for other in [0, 1, 2, 4] {
            XCTAssertEqual(after[other].x, before[other].x, accuracy: 2, "item \(other) moved in x while editing item 3")
            XCTAssertEqual(after[other].y, before[other].y, accuracy: 2, "item \(other) moved in y while editing item 3")
        }
        XCTAssertNotEqual(after[3].y, before[3].y, "the edited text did not move at all. before=\(before[3]) after=\(after[3])")
    }

    func testDraggingTheNewestTextWhileEditingMovesThatText() {
        addSecondText()
        item(4).doubleTap()
        XCTAssertTrue(app.buttons["format-bold"].waitForExistence(timeout: 10), "editing did not start")
        Thread.sleep(forTimeInterval: 1)
        let before = snapshot()
        drag(4, dx: 0, dy: -60)
        let after = snapshot()
        for other in [0, 1, 2, 3] {
            XCTAssertEqual(after[other].x, before[other].x, accuracy: 2, "item \(other) moved in x while editing item 4")
            XCTAssertEqual(after[other].y, before[other].y, accuracy: 2, "item \(other) moved in y while editing item 4")
        }
        XCTAssertNotEqual(after[4].y, before[4].y, "the edited text did not move at all. before=\(before[4]) after=\(after[4])")
    }

    private func fastDrag(_ index: Int, dx: CGFloat, dy: CGFloat) {
        let start = item(index).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)), withVelocity: .fast, thenHoldForDuration: 0)
    }

    private func assertOnlyMoved(_ moved: Int, before: [(x: Double, y: Double)], after: [(x: Double, y: Double)], line: UInt = #line) {
        for index in 0..<5 where index != moved {
            XCTAssertEqual(after[index].x, before[index].x, accuracy: 2, "item \(index) moved in x but \(moved) was dragged", line: line)
            XCTAssertEqual(after[index].y, before[index].y, accuracy: 2, "item \(index) moved in y but \(moved) was dragged", line: line)
        }
        XCTAssertNotEqual(after[moved].x, before[moved].x, "the dragged item \(moved) did not move", line: line)
    }

    func testFastDragOfAnotherTextAfterSelectingOne() {
        addSecondText()
        item(3).tap()
        let before = snapshot()
        fastDrag(4, dx: 50, dy: 0)
        assertOnlyMoved(4, before: before, after: snapshot())
    }

    func testFastDragOfTheOlderTextAfterSelectingTheNewer() {
        addSecondText()
        item(4).tap()
        let before = snapshot()
        fastDrag(3, dx: -50, dy: 0)
        assertOnlyMoved(3, before: before, after: snapshot())
    }

    func testFastDragOfAStickerAfterSelectingText() {
        addSecondText()
        item(3).tap()
        let before = snapshot()
        fastDrag(1, dx: 50, dy: 0)
        assertOnlyMoved(1, before: before, after: snapshot())
    }
}
