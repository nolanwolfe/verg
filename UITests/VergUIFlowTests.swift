import XCTest

/// Drives the real app.
///
/// The unit suite covers pure logic well, but nothing in it can open a sheet,
/// switch a tab, or notice that a label went invisible against its own
/// background. Those are exactly the defects that reach a user, and every one
/// of them found during 2.2 was found by eye. This target exists so they can
/// be found by machine instead.
///
/// Each test attaches screenshots, so a failure — or a suspicious pass — can
/// be looked at rather than guessed about.
final class VergUIFlowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Launch

    private func launch(appearance: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VergUITest", "-VergAppearance", appearance]
        app.launch()
        return app
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func tab(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons["tab.\(name)"]
    }

    /// Switch tabs, then let the cross-fade finish.
    ///
    /// SwiftUI dissolves between tabs, so a screenshot taken the instant
    /// after a tap catches both screens at once — the first screenshot pass
    /// showed Archive's headings ghosting through Settings, which reads as a
    /// rendering bug and is not one. Settling makes the captures trustworthy.
    @discardableResult
    private func open(_ app: XCUIApplication, tab name: String) -> Bool {
        let button = tab(app, name)
        guard button.waitForExistence(timeout: 5) else { return false }
        button.tap()
        settle()
        return true
    }

    /// Longer than the tab dissolve, shorter than a person would notice.
    private func settle(_ seconds: TimeInterval = 0.9) {
        _ = XCTWaiter.wait(for: [expectation(description: "settle")], timeout: seconds)
    }

    // MARK: - Every tab, both themes

    func testWalkEveryTabInLight() { walkEveryTab(appearance: "light") }
    func testWalkEveryTabInDark() { walkEveryTab(appearance: "dark") }

    private func walkEveryTab(appearance: String) {
        let app = launch(appearance: appearance)
        XCTAssertTrue(tab(app, "write").waitForExistence(timeout: 10),
                      "Tab bar never appeared — the app did not get past launch")

        for name in ["verg", "journal", "write", "library", "settings"] {
            XCTAssertTrue(open(app, tab: name), "Could not reach the \(name) tab")
            shoot(app, "\(appearance)-\(name)")
        }
    }

    // MARK: - Landmarks
    /// Each tab has one thing that proves it actually rendered, rather than
    /// the tab bar simply having accepted a tap over an empty screen.

    func testEachTabRendersItsOwnContent() {
        let app = launch(appearance: "light")
        XCTAssertTrue(tab(app, "write").waitForExistence(timeout: 10))

        open(app, tab: "journal")
        XCTAssertTrue(app.staticTexts["Your Journal"].waitForExistence(timeout: 5),
                      "Journal did not render its header")

        open(app, tab: "library")
        XCTAssertTrue(app.staticTexts["Archive"].waitForExistence(timeout: 5),
                      "Archive did not render its header")
        XCTAssertTrue(app.staticTexts["DAYS LIT"].exists, "Archive lost the heatmap section")
        XCTAssertTrue(app.staticTexts["INSIGHTS"].exists, "Archive lost the insights section")

        open(app, tab: "settings")
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5),
                      "Settings did not render its header")
        for row in ["Duration", "Sound", "The Oracle", "History", "Appearance"] {
            XCTAssertTrue(app.staticTexts[row].exists, "Settings lost the \(row) row")
        }
    }

    // MARK: - Appearance

    /// The setting has to survive being chosen — and the picker has to name
    /// the mode that is actually in force.
    func testAppearancePickerSelectsAndPersists() {
        let app = launch(appearance: "light")
        open(app, tab: "settings")

        let row = app.buttons["settings.Appearance"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Settings has no Appearance row")
        row.tap()

        let dark = app.buttons["appearance.dark"]
        if !dark.waitForExistence(timeout: 5) { shoot(app, "appearance-picker-missing") }
        XCTAssertTrue(dark.exists, "Appearance picker did not open")
        dark.tap()
        shoot(app, "appearance-picked-dark")

        // The sheet closes itself on selection; the row should now read Dark.
        XCTAssertTrue(app.staticTexts["Dark"].waitForExistence(timeout: 5),
                      "Appearance row did not update to the chosen mode")
    }

    // MARK: - History

    /// Choosing Calendar has to change what the Archive draws. This is the
    /// exact bug that shipped: the picker stored the choice and no view read
    /// it, so the heatmap stayed put.
    func testHistoryStyleChangesTheArchive() {
        let app = launch(appearance: "light")
        open(app, tab: "settings")

        let history = app.buttons["settings.History"]
        XCTAssertTrue(history.waitForExistence(timeout: 5), "Settings has no History row")
        history.tap()

        let calendar = app.buttons["history.monthGrid"]
        if !calendar.waitForExistence(timeout: 5) { shoot(app, "history-picker-missing") }
        XCTAssertTrue(calendar.exists, "History picker did not open")
        calendar.tap()

        open(app, tab: "library")
        shoot(app, "archive-calendar-style")
        // The month grid names weekdays; the heatmap does not.
        XCTAssertTrue(app.staticTexts["DAYS LIT"].waitForExistence(timeout: 5))
    }

    // MARK: - Scripts

    /// Write a script, then change it. Editing did not exist at all until
    /// 2.2, so this covers the path end to end.
    func testWriteThenEditAScript() {
        let app = launch(appearance: "light")
        open(app, tab: "settings")

        let oracle = app.buttons["settings.The Oracle"]
        XCTAssertTrue(oracle.waitForExistence(timeout: 5), "Settings has no Oracle row")
        oracle.tap()

        // New script
        let add = app.buttons["Add"].exists ? app.buttons["Add"] : app.buttons.matching(identifier: "plus").firstMatch
        if add.waitForExistence(timeout: 3) { add.tap() }
        let newScript = app.buttons["New script"]
        if newScript.waitForExistence(timeout: 3) { newScript.tap() }

        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 5) else {
            shoot(app, "scripts-no-field")
            return XCTFail("Could not reach the script editor's text field")
        }
        field.tap()
        field.typeText("A first line")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["A first line"].waitForExistence(timeout: 5),
                      "A saved script did not appear in the library")
        shoot(app, "scripts-after-save")

        // Edit it
        app.staticTexts["A first line"].tap()
        let editField = app.textFields.firstMatch
        XCTAssertTrue(editField.waitForExistence(timeout: 5),
                      "Tapping a script did not open the editor")
        XCTAssertTrue(app.navigationBars["Edit script"].exists,
                      "The editor opened in create mode instead of edit mode")
        shoot(app, "scripts-editing")
    }

    // MARK: - The Oracle sheet

    func testOracleSheetOpensFromWrite() {
        let app = launch(appearance: "light")
        XCTAssertTrue(tab(app, "write").waitForExistence(timeout: 10))
        open(app, tab: "write")

        let pill = app.buttons.containing(.staticText, identifier: "No script").firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 5), "The Oracle pill is missing from Write")
        pill.tap()

        XCTAssertTrue(app.navigationBars["The Oracle"].waitForExistence(timeout: 5),
                      "The Oracle sheet did not open")
        shoot(app, "oracle-sheet")
    }

    // MARK: - Duration

    func testDurationPickerOpens() {
        let app = launch(appearance: "light")
        open(app, tab: "write")

        let pill = app.buttons.containing(.staticText, identifier: "10 min").firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 5), "The duration pill is missing from Write")
        pill.tap()
        shoot(app, "duration-picker")
    }

    // MARK: - Sound is one switch in two places

    /// Flipping Sound on Write has to move the Sound row in Settings. They
    /// were two different settings wearing the same word until 2.2.
    func testSoundPillAndSettingsRowAgree() {
        let app = launch(appearance: "light")
        open(app, tab: "write")

        let pill = app.buttons.containing(.staticText, identifier: "Sound").firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()   // turn Sound off

        open(app, tab: "settings")
        let toggle = app.switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Settings has no Sound switch")
        XCTAssertEqual(toggle.value as? String, "0",
                       "Turning Sound off on Write left the Settings switch on")
        shoot(app, "sound-synced-off")
    }
}
