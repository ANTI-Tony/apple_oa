import XCTest

/// End-to-end checks against the running app, launched with in-memory
/// storage and sample content (`-uiTesting`).
final class ReportingBuilderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp(windowSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        // Key/value pairs first, the valueless flag last (see LaunchOverrides).
        app.launchArguments = windowSize.map { ["-windowSize", $0] } ?? []
        app.launchArguments.append("-uiTesting")
        app.launch()
        return app
    }

    @MainActor
    func testCompactWindowOffersEditPreviewSwitch() {
        let app = launchApp(windowSize: "640x640")
        let paneSwitch = app.descendants(matching: .any)["layout.paneSwitch"]
        XCTAssertTrue(paneSwitch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 5), "compact layout opens on the editor")
        paneSwitch.radioButtons["Preview"].click()
        XCTAssertTrue(app.buttons["preview.accessibilityBadge"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWideWindowHasNoPaneSwitch() {
        let app = launchApp(windowSize: "1400x860")
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["layout.paneSwitch"].exists)
    }

    @MainActor
    func testLaunchShowsSeededCardInEditorAndPreview() {
        let app = launchApp()
        let title = app.textFields["editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.value as? String, "Weekly status")
        let badge = app.buttons["preview.accessibilityBadge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        XCTAssertTrue(badge.label.contains("AA ready"), "badge label was: \(badge.label)")
    }

    @MainActor
    func testNewCardShortcutCreatesAndDuplicateCopiesIt() {
        let app = launchApp()
        let title = app.textFields["editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Weekly status")
        app.typeKey("d", modifierFlags: .command)
        let predicate = NSPredicate(format: "value == %@", "Weekly status copy")
        expectation(for: predicate, evaluatedWith: title)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testAddTextBlockFromEditor() {
        let app = launchApp()
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        let addBlock = app.descendants(matching: .any)["editor.addBlock"]
        XCTAssertTrue(addBlock.waitForExistence(timeout: 5))
        let blocksBefore = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Text block'")).count
        addBlock.click()
        let textItem = app.menuItems["Text"]
        XCTAssertTrue(textItem.waitForExistence(timeout: 5))
        textItem.click()
        let predicate = NSPredicate(format: "label BEGINSWITH 'Text block'")
        let query = app.descendants(matching: .any).matching(predicate)
        let grew = NSPredicate { _, _ in query.count > blocksBefore }
        expectation(for: grew, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testCopyForEmailWritesRichPasteboard() {
        let app = launchApp()
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        app.typeKey("c", modifierFlags: [.command, .shift])
        let banner = app.descendants(matching: .any)["notice.banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        let types = Set(NSPasteboard.general.types ?? [])
        XCTAssertTrue(types.contains(.html), "types: \(types)")
        XCTAssertTrue(types.contains(.rtfd), "types: \(types)")
        XCTAssertTrue(types.contains(.string), "types: \(types)")
    }

    @MainActor
    func testAccessibilityAudit() throws {
        let app = launchApp()
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
    }
}
