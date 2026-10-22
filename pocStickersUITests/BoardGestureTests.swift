import XCTest

final class BoardGestureTests: XCTestCase {
    private let app = XCUIApplication()

    struct ItemState {
        var x: Double
        var y: Double
        var scale: Double
        var rotation: Double
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchArguments = ["-autoBoard"]
        app.launch()
    }

    private func item(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "item-\(index)").firstMatch
    }

    private func state(_ index: Int) -> ItemState {
        let element = item(index)
        XCTAssertTrue(element.waitForExistence(timeout: 10), "item-\(index) not found")
        let text = element.value as? String ?? ""
        var values: [String: Double] = [:]
        for pair in text.split(separator: " ") {
            let parts = pair.split(separator: "=")
            if parts.count == 2, let number = Double(parts[1]) {
                values[String(parts[0])] = number
            }
        }
        return ItemState(
            x: values["x"] ?? .nan,
            y: values["y"] ?? .nan,
            scale: values["s"] ?? .nan,
            rotation: values["r"] ?? .nan
        )
    }

    func testDragMovesOnlyThatItem() {
        let before = (0..<4).map(state)
        let start = item(1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 50, dy: 40)))
        let after = (0..<4).map(state)

        XCTAssertEqual(after[1].x - before[1].x, 50, accuracy: 10, "dragged item x")
        XCTAssertEqual(after[1].y - before[1].y, 40, accuracy: 10, "dragged item y")
        for other in [0, 2, 3] {
            XCTAssertEqual(after[other].x, before[other].x, accuracy: 2, "item \(other) moved in x")
            XCTAssertEqual(after[other].y, before[other].y, accuracy: 2, "item \(other) moved in y")
        }
    }

    func testRotateChangesAngleNotPosition() {
        let before = state(0)
        item(0).rotate(.pi / 2, withVelocity: 1)
        let after = state(0)

        XCTAssertEqual(after.rotation, 90, accuracy: 25, "rotation after a 90 degree twist")
        XCTAssertEqual(after.x, before.x, accuracy: 6, "item drifted in x while rotating")
        XCTAssertEqual(after.y, before.y, accuracy: 6, "item drifted in y while rotating")
        XCTAssertEqual(after.scale, before.scale, accuracy: 0.15, "rotation changed the scale")
    }

    func testPinchChangesScaleNotPosition() {
        let before = state(0)
        item(0).pinch(withScale: 1.8, velocity: 1)
        let after = state(0)

        XCTAssertEqual(after.scale, 1.8, accuracy: 0.4, "scale after pinching out")
        XCTAssertEqual(after.x, before.x, accuracy: 6, "item drifted in x while pinching")
        XCTAssertEqual(after.y, before.y, accuracy: 6, "item drifted in y while pinching")
        XCTAssertEqual(after.rotation, before.rotation, accuracy: 15, "pinch rotated the item")
    }

    func testDragStillWorksAfterRotate() {
        item(0).rotate(.pi / 3, withVelocity: 1)
        let before = state(0)
        let start = item(0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 40, dy: 30)))
        let after = state(0)

        XCTAssertEqual(after.x - before.x, 40, accuracy: 10, "drag after rotate x")
        XCTAssertEqual(after.y - before.y, 30, accuracy: 10, "drag after rotate y")
    }

    func testDragStillWorksAfterPinch() {
        item(0).pinch(withScale: 1.5, velocity: 1)
        let before = state(0)
        let start = item(0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -40, dy: 30)))
        let after = state(0)

        XCTAssertEqual(after.x - before.x, -40, accuracy: 10, "drag after pinch x")
        XCTAssertEqual(after.y - before.y, 30, accuracy: 10, "drag after pinch y")
    }
}
