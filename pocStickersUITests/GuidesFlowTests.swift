import XCTest

final class GuidesFlowTests: XCTestCase {
    private let app = XCUIApplication()

    func testWriteFlowShowsGuidesAndPlacesAQuestion() {
        app.launchArguments = ["-resetBoard"]
        app.launch()

        let write = app.buttons["write"]
        XCTAssertTrue(write.waitForExistence(timeout: 15), "Home screen has no Write button")
        write.tap()

        let next = app.buttons["feelings-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10), "feelings form did not open")
        XCTAssertFalse(next.isEnabled, "Continue should be disabled until a feeling is chosen")
        app.buttons["feeling-anxious"].tap()
        XCTAssertTrue(next.isEnabled, "Continue should be enabled after choosing a feeling")
        next.tap()

        let needContinue = app.buttons["needs-continue"]
        XCTAssertTrue(needContinue.waitForExistence(timeout: 10), "needs form did not open")
        XCTAssertFalse(needContinue.isEnabled, "Continue should be disabled until a need is chosen")
        app.buttons["need-makeSense"].tap()
        XCTAssertTrue(needContinue.isEnabled, "Continue should be enabled after choosing a need")
        needContinue.tap()

        let guide = app.buttons["guide-0"]
        XCTAssertTrue(guide.waitForExistence(timeout: 90), "guides did not appear")
        XCTAssertTrue(app.buttons["guide-2"].exists, "expected three guides")

        let before = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'item-'")).count
        guide.tap()
        let after = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'item-'")).count
        XCTAssertEqual(after, before + 1, "tapping a guide should place one text item")

        app.buttons["guides-dismiss"].tap()
        XCTAssertFalse(app.buttons["guide-0"].waitForExistence(timeout: 3), "guides did not dismiss")
    }

    func testBackFromNeedsKeepsTheFeeling() {
        app.launchArguments = ["-resetBoard"]
        app.launch()
        app.buttons["write"].tap()
        app.buttons["feeling-sad"].tap()
        app.buttons["feelings-continue"].tap()
        XCTAssertTrue(app.buttons["needs-back"].waitForExistence(timeout: 10), "needs form did not open")
        app.buttons["needs-back"].tap()
        let next = app.buttons["feelings-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10), "Back did not return to the feelings form")
        XCTAssertTrue(next.isEnabled, "the chosen feeling was forgotten after going back")
    }

    private func runFlow(feeling: String, need: String) {
        app.buttons["write"].tap()
        app.buttons["feeling-\(feeling)"].tap()
        app.buttons["feelings-continue"].tap()
        XCTAssertTrue(app.buttons["need-\(need)"].waitForExistence(timeout: 10), "needs form did not open")
        app.buttons["need-\(need)"].tap()
        app.buttons["needs-continue"].tap()
        XCTAssertTrue(app.buttons["guide-0"].waitForExistence(timeout: 90), "guides did not appear")
        app.buttons["guides-dismiss"].tap()
    }

    func testInspireMeShowsEmptyStateThenHistory() {
        app.launchArguments = ["-resetBoard"]
        app.launch()
        app.buttons["tab-journal"].tap()
        let inspire = app.buttons["inspire"]
        XCTAssertTrue(inspire.waitForExistence(timeout: 10), "board has no Inspire Me button")
        inspire.tap()
        XCTAssertTrue(app.staticTexts["inspire-empty"].waitForExistence(timeout: 10), "empty state missing")
        app.buttons["inspire-close"].tap()
        app.buttons["board-back"].tap()

        runFlow(feeling: "sad", need: "untangle")
        app.buttons["board-back"].tap()
        runFlow(feeling: "happy", need: "understand")

        inspire.tap()
        XCTAssertTrue(app.buttons["inspire-0-0"].waitForExistence(timeout: 10), "newest set missing")
        XCTAssertTrue(app.buttons["inspire-1-0"].exists, "previous set missing")
        XCTAssertFalse(app.buttons["inspire-2-0"].exists, "unexpected third set")

        let before = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'item-'")).count
        app.buttons["inspire-1-1"].tap()
        XCTAssertFalse(app.buttons["inspire-close"].waitForExistence(timeout: 3), "sheet should close after picking")
        let after = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'item-'")).count
        XCTAssertEqual(after, before + 1, "picking a past question should place one text item")
    }

    func testGuideHistorySurvivesRelaunch() {
        app.launchArguments = ["-resetBoard"]
        app.launch()
        runFlow(feeling: "anxious", need: "makeSense")
        Thread.sleep(forTimeInterval: 2)

        app.terminate()
        app.launchArguments = []
        app.launch()
        let journal = app.buttons["tab-journal"]
        XCTAssertTrue(journal.waitForExistence(timeout: 15))
        journal.tap()
        app.buttons["inspire"].tap()
        XCTAssertTrue(app.buttons["inspire-0-0"].waitForExistence(timeout: 10), "history did not survive relaunch")
    }

    func testCancelReturnsHome() {
        app.launchArguments = ["-resetBoard"]
        app.launch()
        app.buttons["write"].tap()
        app.buttons["feelings-cancel"].tap()
        XCTAssertTrue(app.buttons["write"].waitForExistence(timeout: 10), "Cancel did not return Home")
    }
}
