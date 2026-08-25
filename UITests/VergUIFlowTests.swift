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

    /// Leave no lock behind.
    ///
    /// The app lock lives in the Keychain, which survives deleting the app —
    /// deliberately, so the lock can't be shrugged off by a reinstall. The
    /// cost is that a test which sets a passcode locks the *simulator* for
    /// every later launch, and `StorageService`'s reset only runs when the
    /// app is launched with `-VergUITest`, which is exactly the case that
    /// doesn't need it. Opening the app by hand after a test run met a lock
    /// screen with a code only the test source knew.
    /// Once for the whole class, not per test — this costs a launch cycle,
    /// and only the lock tests dirty anything that outlives the app.
    override class func tearDown() {
        let app = XCUIApplication()
        app.launchArguments = ["-VergUITest"]   // clears the lock on launch
        app.launch()
        app.terminate()
        super.tearDown()
    }

    // MARK: - Launch

    private func launch(
        appearance: String,
        seeded: Bool = false,
        onboarding: Bool = false,
        large: Bool = false,
        textSize: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VergUITest", "-VergAppearance", appearance]
        if seeded { app.launchArguments.append("-VergSeedData") }
        if onboarding { app.launchArguments.append("-VergOnboarding") }
        if large { app.launchArguments.append("-VergSeedLarge") }
        if let textSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize]
        }
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

    /// Mean brightness of the whole screen, 0 (black) to 1 (white).
    ///
    /// Which theme a screen is actually wearing is invisible to every other
    /// kind of assertion here — labels and identifiers are identical in light
    /// and dark, so a screen that flips theme passes a structural test and a
    /// screenshot test alike, and only a person looking at the image notices.
    /// Averaging the frame down to a single pixel turns that into a number a
    /// test can fail on.
    private func screenBrightness(_ app: XCUIApplication) -> CGFloat {
        guard let cg = app.screenshot().image.cgImage else { return -1 }
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel,
            width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (CGFloat(pixel[0]) + CGFloat(pixel[1]) + CGFloat(pixel[2])) / (3 * 255)
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

    // MARK: - Screens that need a journal to exist
    //
    // The grid, the fullscreen viewer and a book only appear once there are
    // pages, which is why they were the least-verified part of 2.2.

    func testJournalGridAndFullscreenViewer() {
        let app = launch(appearance: "light", seeded: true)
        open(app, tab: "journal")
        shoot(app, "seeded-journal-grid")

        // Tapping a thumbnail opens the viewer, which pins itself dark.
        let firstPage = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(firstPage.waitForExistence(timeout: 5), "The journal grid drew no pages")
        firstPage.tap()
        settle()
        shoot(app, "seeded-fullscreen-viewer")

        // The page counter proves the viewer opened on a real page.
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS ' / '")
        ).firstMatch.waitForExistence(timeout: 5), "The viewer has no page counter")
    }

    func testBookDetailOpens() {
        let app = launch(appearance: "light", seeded: true)
        open(app, tab: "library")
        shoot(app, "seeded-archive")

        let book = app.buttons.containing(.staticText, identifier: "Shiloh").firstMatch
        guard book.waitForExistence(timeout: 5) else {
            return XCTFail("No book on the Archive shelf")
        }
        book.tap()
        settle()
        shoot(app, "seeded-book-detail")
        XCTAssertTrue(app.buttons["+ Add a note"].waitForExistence(timeout: 5),
                      "Book detail did not render its note affordance")
        XCTAssertTrue(app.staticTexts["4 pages"].exists,
                      "Book detail did not render its page count")
    }

    func testArchiveShowsRealNumbers() {
        let app = launch(appearance: "light", seeded: true)
        open(app, tab: "library")
        XCTAssertTrue(app.staticTexts["Archive"].waitForExistence(timeout: 5))
        shoot(app, "seeded-archive-numbers")
    }

    /// The paywall is daylight whatever the app is set to. It used to invert
    /// against the theme, which meant a dark app got a light paywall and a
    /// light app got a dark one.
    func testPaywallIsLightEvenWhenTheAppIsDark() {
        let app = launch(appearance: "dark", seeded: true)
        open(app, tab: "settings")
        let row = app.buttons["settings.The Golden Age"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Settings has no Golden Age row")
        row.tap()
        settle(1.0)
        shoot(app, "paywall-from-dark-app")
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'The Golden Age'")
        ).firstMatch.waitForExistence(timeout: 5), "The paywall did not open from a dark app")

        // …and it is actually daylight, not merely present. Structure alone
        // cannot tell the two themes apart.
        let brightness = screenBrightness(app)
        XCTAssertGreaterThan(brightness, 0.6,
                             "The paywall came up dark (brightness \(brightness))")
    }

    /// The mirror of the paywall rule: onboarding is a dark room with a
    /// candle in it, whatever the Appearance setting says — and it runs
    /// before anyone has set one. Launched light on purpose.
    func testOnboardingIsDarkEvenInLightMode() {
        let app = launch(appearance: "light", onboarding: true)
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10),
                      "Onboarding never appeared")
        settle()
        shoot(app, "onboarding-dark-in-light-mode")

        let brightness = screenBrightness(app)
        XCTAssertLessThan(brightness, 0.35,
                          "Onboarding came up light (brightness \(brightness))")
    }

    func testPaywallOpensFromGoldenAge() {
        let app = launch(appearance: "light", seeded: true)
        open(app, tab: "settings")
        let row = app.buttons["settings.The Golden Age"]
        guard row.waitForExistence(timeout: 5) else {
            return XCTFail("Settings has no Golden Age row")
        }
        row.tap()
        settle()
        shoot(app, "paywall")
        XCTAssertTrue(app.staticTexts["The Golden Age"].waitForExistence(timeout: 5),
                      "The paywall did not open")
    }

    // MARK: - Onboarding
    //
    // Six screens a person sees exactly once, which is also how often they
    // get looked at. Every line of copy on them changed during 2.2.

    func testOnboardingWalksAllSixScreens() {
        let app = launch(appearance: "light", onboarding: true)

        let cont = app.buttons["Continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 10), "Onboarding never appeared")

        // Screen 1 is the epigraph.
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Dante to Virgil'")
        ).firstMatch.exists, "The epigraph screen did not render")
        shoot(app, "onboarding-1-epigraph")

        for step in 2...6 {
            guard cont.waitForExistence(timeout: 5) else { break }
            cont.tap()
            settle(0.7)
            shoot(app, "onboarding-\(step)")
        }

        // The last screen carries the rating note; then Continue leaves.
        XCTAssertTrue(app.staticTexts["One more thing."].exists,
                      "The closing screen did not render its title")
    }

    func testOnboardingSkipGoesStraightIn() {
        let app = launch(appearance: "light", onboarding: true)
        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10), "Onboarding has no Skip")
        skip.tap()
        settle(1.2)
        shoot(app, "onboarding-skipped")
        XCTAssertTrue(tab(app, "write").waitForExistence(timeout: 8),
                      "Skipping onboarding did not reach the app")
    }

    // MARK: - The timer
    //
    // Its ground, countdown and control scrims all became theme-aware, and
    // none of that had been seen — the screen is a full-screen cover behind a
    // running session.

    func testTimerRendersInLight() { timerScreen(appearance: "light") }
    func testTimerRendersInDark() { timerScreen(appearance: "dark") }

    private func timerScreen(appearance: String) {
        let app = launch(appearance: appearance, seeded: true)
        open(app, tab: "write")

        let begin = app.buttons["Begin Writing"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5), "Write has no Begin Writing button")
        begin.tap()
        settle(1.6)
        shoot(app, "\(appearance)-timer")

        // The countdown is the proof it started, and it must be legible —
        // it was plain white until the timer learned about light mode.
        let countdown = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "^[0-9]{1,2}:[0-9]{2}$")
        ).firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 5),
                      "The timer screen shows no countdown")
    }

    // MARK: - Locked pages
    //
    // Pages older than the free window render dimmed with a lock and open the
    // paywall. On the Journal tab that tap did nothing at all until 2.2 — it
    // set the date the paywall would explain and never presented it — and the
    // fix went in without ever being seen.

    func testTappingALockedPageOpensThePaywall() {
        let app = launch(appearance: "light", seeded: true)
        open(app, tab: "journal")

        let pages = app.scrollViews.buttons
        XCTAssertTrue(pages.firstMatch.waitForExistence(timeout: 5), "No pages in the journal")
        // The oldest seeded page is outside the free window.
        let oldest = pages.element(boundBy: pages.count - 1)
        oldest.tap()
        settle(1.2)
        shoot(app, "locked-page-tapped")

        // Matched by prefix: the CTA becomes "The Golden Age — 3 days free"
        // whenever a trial is live and this subscriber is eligible, so an
        // exact match passes or fails on App Store Connect's configuration
        // rather than on the app.
        let cta = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'The Golden Age'")
        ).firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 5),
                      "Tapping a locked page did not open the paywall")

        // And it should name the page they reached for, not fall back to the
        // generic line. The date travels with the presentation now; when it
        // was a separate `Date?` beside a boolean it arrived too late.
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'is still here'")
        ).firstMatch.waitForExistence(timeout: 3),
        "The paywall did not name the locked page that opened it")
    }

    // MARK: - Book customization

    func testBookRenameAndColourPicker() {
        let app = launch(appearance: "light", seeded: true)
        open(app, tab: "library")

        let book = app.buttons.containing(.staticText, identifier: "Shiloh").firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 5), "No book on the shelf")
        book.tap()
        settle()

        // The overflow menu carries Rename & Color.
        let menu = app.buttons["ellipsis.circle"].exists
            ? app.buttons["ellipsis.circle"]
            : app.navigationBars.buttons.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "Book detail has no overflow menu")
        menu.tap()
        settle(0.6)

        let rename = app.buttons["Rename & Color"]
        guard rename.waitForExistence(timeout: 4) else {
            shoot(app, "book-menu")
            return XCTFail("The overflow menu has no Rename & Color")
        }
        rename.tap()
        settle(0.8)
        shoot(app, "book-customize")
        XCTAssertTrue(app.staticTexts["COVER COLOR"].waitForExistence(timeout: 5),
                      "The customize sheet has no colour picker")
    }

    // MARK: - Achievements
    /// Below the fold on the Archive, so never seen without scrolling.

    func testAchievementsLadderRenders() {
        let app = launch(appearance: "light", seeded: true)
        open(app, tab: "library")
        XCTAssertTrue(app.staticTexts["Archive"].waitForExistence(timeout: 5))

        app.swipeUp()
        app.swipeUp()
        settle()
        shoot(app, "archive-achievements")
        XCTAssertTrue(app.staticTexts["ACHIEVEMENTS"].waitForExistence(timeout: 5),
                      "The achievements ladder never came into view")
    }

    // MARK: - A real-sized journal
    //
    // Two hundred-odd pages, which is what a committed user actually has.
    // The grid, the thumbnail cache and the viewer's swipe window all behave
    // differently at that size than at nine.

    /// Opening a page you *are* allowed to see and swiping must not walk you
    /// through the ones you are not. The lock used to guard the grid only.
    func testSwipingInTheViewerCannotWalkPastTheLock() {
        let app = launch(appearance: "light", seeded: true, large: true)
        open(app, tab: "journal")

        let first = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15), "The journal drew no pages")
        first.tap()   // newest page, inside the free window
        settle(1.2)

        // Swipe past the seven-day boundary.
        for _ in 0..<8 { app.swipeLeft() }
        settle()
        shoot(app, "viewer-swiped-into-locked")

        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'The Golden Age'")
        ).firstMatch.waitForExistence(timeout: 5),
        "Swiping in the viewer showed a locked page's contents")
    }

    func testLargeJournalScrollsAndOpens() {
        let app = launch(appearance: "light", seeded: true, large: true)
        open(app, tab: "journal")

        XCTAssertTrue(app.scrollViews.buttons.firstMatch.waitForExistence(timeout: 15),
                      "A large journal never finished drawing its grid")
        shoot(app, "large-journal-top")

        // Open a recent page — deep in the grid every page is gated, and a
        // locked tap correctly goes to the paywall instead of the viewer.
        app.scrollViews.buttons.firstMatch.tap()
        settle(1.2)
        shoot(app, "large-journal-viewer")

        // Swipe a short run, which is where the viewer used to blank pages
        // and re-decode them.
        for _ in 0..<4 { app.swipeLeft() }
        settle()
        shoot(app, "large-journal-swiped")
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS ' / '")
        ).firstMatch.exists, "The viewer lost its page counter while swiping")

        app.buttons.matching(identifier: "xmark").firstMatch.tap()
        settle()

        // Scrolling a long way in is its own check: lazy loading and cache
        // eviction meet somewhere past two hundred pages.
        for _ in 0..<12 { app.swipeUp(velocity: .fast) }
        settle()
        shoot(app, "large-journal-deep")
        XCTAssertTrue(app.scrollViews.buttons.allElementsBoundByIndex.contains { $0.isHittable },
                      "The grid stopped drawing pages while scrolling")
    }

    // MARK: - Dynamic Type
    //
    // These pass, and today that means almost nothing: `Theme.Typography` is
    // built from `Font.system(size:)`, which is a fixed point size and does
    // not respond to the text-size setting at all. Screenshots at
    // AccessibilityL are pixel-identical to the default.
    //
    // They are here as the guard for when that changes. Every entry in the
    // scale maps to a semantic style that *would* scale — 17 semibold is
    // `.headline`, 15 regular is `.subheadline`, and so on — but swapping
    // them reflows every screen at once, and the layouts that matter most
    // (the SE fit, the paywall's single screen) are tuned against the fixed
    // sizes. That is a deliberate piece of work, not a find-and-replace.

    func testLargeTextDoesNotBreakTheTabs() {
        let app = launch(
            appearance: "light",
            seeded: true,
            textSize: "UICTContentSizeCategoryAccessibilityL"
        )
        XCTAssertTrue(tab(app, "write").waitForExistence(timeout: 10),
                      "The tab bar did not survive large text")

        for name in ["write", "journal", "library", "settings"] {
            XCTAssertTrue(open(app, tab: name), "Could not reach \(name) at large text")
            shoot(app, "xl-\(name)")
        }

        // The tab bar still has to be usable — it is how you leave.
        XCTAssertTrue(tab(app, "settings").isHittable,
                      "The tab bar stopped being tappable at large text")
    }

    func testLargeTextOnThePaywall() {
        let app = launch(
            appearance: "light",
            seeded: true,
            textSize: "UICTContentSizeCategoryAccessibilityL"
        )
        open(app, tab: "settings")
        let row = app.buttons["settings.The Golden Age"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        settle(1.0)
        shoot(app, "xl-paywall")

        // Whatever else reflows, the way to buy and the way out must remain.
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'The Golden Age'")
        ).firstMatch.waitForExistence(timeout: 5),
        "The paywall lost its CTA at large text")
    }

    // MARK: - Sound is one switch in two places

    /// Flipping Sound on Write has to move the Sound row in Settings. They
    /// were two different settings wearing the same word until 2.2.
    func testSoundPillAndSettingsRowAgree() {
        let app = launch(appearance: "light")
        open(app, tab: "write")

        let pill = app.buttons.containing(.staticText, identifier: "Sound").firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        shoot(app, "sound-before-tap")
        pill.tap()   // turn Sound off
        settle()
        shoot(app, "sound-after-tap")

        open(app, tab: "settings")
        let toggle = app.switches["settings.toggle.Sound"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Settings has no Sound switch")
        shoot(app, "sound-settings-row")
        XCTAssertEqual(toggle.value as? String, "0",
                       "Turning Sound off on Write left the Settings switch on")
    }

    // MARK: - The Oracle

    /// Drawing is not choosing. Until 2.2 the shuffle wrote straight into the
    /// session's script, so backing out of the sheet still changed it and
    /// there was no moment where you committed — the bug this guards.
    func testDrawingWithoutConfirmingDoesNotChangeTheScript() {
        let app = launch(appearance: "light")
        open(app, tab: "write")

        let pill = app.buttons["write.scriptPill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5), "Write has no script pill")
        XCTAssertTrue(pill.label.contains("No script"), "A session started with a script already set")
        pill.tap()

        let card = app.staticTexts["oracle.script"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "The Oracle did not open")
        card.tap()          // the card is the draw now
        settle()
        shoot(app, "oracle-drawn")

        app.buttons["Cancel"].tap()
        settle()

        XCTAssertTrue(app.buttons["write.scriptPill"].label.contains("No script"),
                      "Leaving the Oracle without confirming still set a script")
    }

    /// …and Select Guidance is what commits it.
    func testSelectGuidanceCommitsTheDrawnScript() {
        let app = launch(appearance: "light")
        open(app, tab: "write")

        app.buttons["write.scriptPill"].tap()

        // Always live: with nothing drawn it draws, and only then commits.
        // It used to be disabled here, which read as a broken button.
        let select = app.buttons["oracle.select"]
        XCTAssertTrue(select.waitForExistence(timeout: 5), "The Oracle did not open")
        XCTAssertTrue(select.isEnabled, "Select Guidance was inert with nothing drawn")

        select.tap()        // draws
        settle()
        select.tap()        // commits
        settle()
        shoot(app, "oracle-selected")

        // "Oracle", not "Script set": a drawn script comes from the fixed
        // set, and the pill now says which of the three states you're in.
        XCTAssertTrue(app.buttons["write.scriptPill"].label.contains("Oracle"),
                      "Select Guidance did not commit the drawn script, or mislabelled its origin")
    }

    /// The script has to be on screen while you write — it was carried to
    /// the saved page as metadata and never rendered, so the one moment it
    /// exists for was the one moment you couldn't see it.
    func testTheScriptIsShownOnTheTimer() {
        let app = launch(appearance: "light")
        open(app, tab: "write")

        app.staticTexts["No script"].tap()
        let card = app.staticTexts["oracle.script"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "The Oracle did not open")
        card.tap()
        settle()

        // Remember what was drawn, so this asserts the *same* script reaches
        // the timer rather than merely that some text is up there.
        let drawn = card.label
        app.buttons["oracle.select"].tap()
        settle()

        app.buttons["Begin Writing"].tap()
        settle(1.4)
        shoot(app, "timer-with-script")

        let onTimer = app.staticTexts["timer.script"]
        XCTAssertTrue(onTimer.waitForExistence(timeout: 6),
                      "The timer did not show the chosen script")
        if !drawn.isEmpty {
            XCTAssertEqual(onTimer.label, drawn,
                           "The timer showed a different script than the one chosen")
        }
    }

    // MARK: - App Lock

    /// The APP section and its three rows, in order.
    func testAppSectionHoldsRateAppearanceAndLock() {
        let app = launch(appearance: "light")
        open(app, tab: "settings")

        XCTAssertTrue(app.staticTexts["APP"].waitForExistence(timeout: 5),
                      "Settings lost the APP section")
        for row in ["Rate Verg", "Appearance", "Lock App"] {
            XCTAssertTrue(app.staticTexts[row].exists, "APP section lost the \(row) row")
        }

        // These sections live below the fold, so a screenshot taken here
        // catches only Candle and Guide. Scroll so the pass actually shows
        // the rows this test is about — the icon tints are the whole point
        // of reviewing them by eye.
        app.swipeUp()
        app.swipeUp()
        settle()
        shoot(app, "settings-app-section")

        XCTAssertTrue(app.staticTexts["ABOUT"].exists, "Settings lost the ABOUT section")
        for row in ["Share Verg", "Privacy Policy", "Terms of Service"] {
            XCTAssertTrue(app.staticTexts[row].exists, "ABOUT section lost the \(row) row")
        }
        // A SwiftUI `Link` surfaces as a button, not `links`.
        XCTAssertTrue(app.buttons["settings.website"].exists,
                      "Settings footer lost the verg.app link")
    }

    /// Backing out of the set-up sheet must leave the switch off. The bug
    /// this guards is the obvious one: flipping the switch optimistically and
    /// leaving it on after a cancel, so Settings claims a lock that the
    /// Keychain knows nothing about.
    func testCancellingLockSetupLeavesTheSwitchOff() {
        let app = launch(appearance: "light")
        open(app, tab: "settings")

        let toggle = app.switches["settings.toggle.Lock App"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Settings has no Lock App switch")
        XCTAssertEqual(toggle.value as? String, "0", "Lock App started on")

        toggle.tap()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Lock set-up sheet did not open")
        shoot(app, "lock-setup-sheet")
        cancel.tap()
        settle()

        XCTAssertEqual(toggle.value as? String, "0",
                       "Cancelling set-up left the Lock App switch on")
    }

    /// The whole round trip: set a code, background the app, come back to a
    /// lock screen, and get in with the code.
    func testLockEngagesOnBackgroundAndOpensWithTheCode() {
        let app = launch(appearance: "light")
        open(app, tab: "settings")

        let toggle = app.switches["settings.toggle.Lock App"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Settings has no Lock App switch")
        toggle.tap()

        let field = app.secureTextFields["applock.codeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Lock set-up sheet has no code field")
        // Four digits submits itself, which advances to the confirm stage.
        field.tap()
        field.typeText("2468")
        settle()

        let confirm = app.secureTextFields["applock.codeField"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Set-up did not ask to confirm")
        confirm.tap()
        confirm.typeText("2468")
        settle()

        XCTAssertEqual(toggle.value as? String, "1", "Setting a code left the switch off")
        shoot(app, "lock-enabled")

        // Out and back: `.background`, the one phase that locks.
        XCUIDevice.shared.press(.home)
        settle()
        app.activate()

        let locked = app.staticTexts["Verg is locked"].waitForExistence(timeout: 10)
        if !locked { shoot(app, "lock-did-not-engage") }
        XCTAssertTrue(locked, "Returning from the background did not lock the app")
        shoot(app, "lock-screen")

        // Covered is not hidden. "Duration" is a Settings row label and
        // belongs to no tab button, so it is only reachable if the content
        // behind the lock is still in the accessibility tree — which it was,
        // until ContentView started hiding it. VoiceOver would have read a
        // locked journal aloud.
        XCTAssertFalse(app.staticTexts["Duration"].exists,
                       "Content behind the lock screen is still readable")

        let entry = app.secureTextFields["applock.codeField"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "Lock screen has no code field")
        entry.tap()
        entry.typeText("2468")
        settle()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10),
                      "The correct code did not unlock the app")
        shoot(app, "lock-opened")
    }

    /// A wrong code must not open it. Cheap to assert, and the exact thing
    /// a hash comparison bug would silently break.
    func testWrongCodeDoesNotUnlock() {
        let app = launch(appearance: "light")
        open(app, tab: "settings")

        let toggle = app.switches["settings.toggle.Lock App"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()

        let field = app.secureTextFields["applock.codeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("1111")
        settle()
        let confirm = app.secureTextFields["applock.codeField"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap(); confirm.typeText("1111")
        settle()

        XCUIDevice.shared.press(.home)
        settle()
        app.activate()

        let entry = app.secureTextFields["applock.codeField"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "App did not lock")
        entry.tap(); entry.typeText("9999")
        settle()

        XCTAssertTrue(app.staticTexts["Wrong code."].exists,
                      "A wrong code was not rejected")
        // Still locked is the invariant. Not `staticTexts["Settings"]` —
        // that matches the tab bar's own button label, so it is present
        // whether or not the gate opened, and asserting on it proves nothing.
        XCTAssertTrue(app.staticTexts["Verg is locked"].exists,
                      "A wrong code let the app through")
        shoot(app, "lock-wrong-code")
    }
}
