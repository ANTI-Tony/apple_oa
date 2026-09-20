import XCTest

/// End-to-end checks against the running app, launched with in-memory
/// storage and sample content (`-uiTesting`).
final class ReportingBuilderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// - Parameter overrides: `LaunchOverrides` keys without the dash, e.g. `["demoState": "listening"]`.
    @MainActor
    private func launchApp(windowSize: String? = nil, overrides: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        // Key/value pairs first, the valueless flag last (see LaunchOverrides).
        app.launchArguments = windowSize.map { ["-windowSize", $0] } ?? []
        for (key, value) in overrides.sorted(by: { $0.key < $1.key }) {
            app.launchArguments += ["-\(key)", value]
        }
        app.launchArguments.append("-uiTesting")
        app.launch()
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    func testLaunchShowsSeededCardEditableOnTheCanvas() {
        let app = launchApp()
        let title = app.textFields["editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.value as? String, "Weekly status")
        let status = element("toolbar.accessibility", in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.hasPrefix("Accessible"), "toolbar status was: \(status.label)")
    }

    @MainActor
    func testTypingOnTheCardRenamesIt() {
        let app = launchApp()
        let title = app.textFields["editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.click()
        app.typeKey("a", modifierFlags: .command)
        title.typeText("Quarterly review")
        let renamed = NSPredicate(format: "value == %@", "Quarterly review")
        expectation(for: renamed, evaluatedWith: title)
        waitForExpectations(timeout: 5)
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
    func testAddingTextSelectsTheNewBlock() {
        let app = launchApp()
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        let selected = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Text block, selected'"))
        XCTAssertEqual(selected.count, 0)
        let addText = element("canvas.addText", in: app)
        XCTAssertTrue(addText.waitForExistence(timeout: 5))
        addText.click()
        let appeared = NSPredicate { _, _ in selected.count == 1 }
        expectation(for: appeared, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testInspectorShowsTheAccessibilityCheck() {
        let app = launchApp(windowSize: "1400x860")
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        element("toolbar.accessibility", in: app).click()
        XCTAssertTrue(element("inspector.accessibilityVerdict", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testCompactWindowHidesTheInspectorUntilAsked() {
        let app = launchApp(windowSize: "640x700")
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(element("inspector.tabs", in: app).exists)
        element("toolbar.format", in: app).click()
        XCTAssertTrue(element("inspector.tabs", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testCopyForEmailWritesRichPasteboard() {
        let app = launchApp()
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        app.typeKey("c", modifierFlags: [.command, .shift])
        XCTAssertTrue(element("notice.banner", in: app).waitForExistence(timeout: 5))
        let types = Set(NSPasteboard.general.types ?? [])
        XCTAssertTrue(types.contains(.html), "types: \(types)")
        XCTAssertTrue(types.contains(.rtfd), "types: \(types)")
        XCTAssertTrue(types.contains(.string), "types: \(types)")
    }

    // MARK: Accessibility features

    @MainActor
    func testUndescribedImageIsFlaggedAndLeadsToItsDescriptionField() {
        let app = launchApp(windowSize: "1400x860", overrides: ["demoState": "missingDescription"])
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        let status = element("toolbar.accessibility", in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("accessibility error"), "toolbar status was: \(status.label)")
        let prompt = element("canvas.addDescription", in: app)
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        prompt.click()
        XCTAssertTrue(element("inspector.imageDescription", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testHearThisCardShowsWhatAScreenReaderWouldSay() {
        // `listening` starts the narration muted, so the test machine stays quiet.
        let app = launchApp(windowSize: "1400x860", overrides: ["demoState": "listening", "inspectorTab": "accessibility"])
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        let listen = element("inspector.listen", in: app)
        XCTAssertTrue(listen.waitForExistence(timeout: 5))
        let speaking = NSPredicate(format: "label == %@", "Stop")
        expectation(for: speaking, evaluatedWith: listen)
        waitForExpectations(timeout: 10)
        // The transcript opens by itself, and the gap is spelled out.
        XCTAssertTrue(app.staticTexts["Image. No description."].waitForExistence(timeout: 5))
        listen.click()
        let stopped = NSPredicate(format: "label == %@", "Hear This Card")
        expectation(for: stopped, evaluatedWith: listen)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testColourVisionSimulationPausesEditingUntilDone() {
        let app = launchApp(overrides: ["visionSimulation": "deuteranopia"])
        let done = element("canvas.simulationDone", in: app)
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["editor.title"].exists)
        done.click()
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 5))
    }

    // MARK: Writing assistance

    @MainActor
    func testNewCardFromNotesCreatesTheDraftedCard() {
        // A canned model: no key, no network, the same parsing and linting as a real reply.
        let app = launchApp(overrides: ["demoDraft": "YES", "stubAssistant": "YES"])
        let create = element("draft.create", in: app)
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        let ready = NSPredicate(format: "isEnabled == true")
        expectation(for: ready, evaluatedWith: create)
        waitForExpectations(timeout: 10)
        create.click()
        let title = app.textFields["editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let drafted = NSPredicate(format: "value == %@", "Atlas weekly status")
        expectation(for: drafted, evaluatedWith: title)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testAccessibilityAudit() throws {
        let app = launchApp()
        XCTAssertTrue(app.textFields["editor.title"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()
    }
}
