import XCTest

/// Produces the App Store screenshots.
///
/// Not a test — nothing here asserts anything about correctness. It exists
/// because the store needs images at exact device resolutions, and driving
/// the real app is the only way to get them without a mockup tool: run this
/// on a 6.9-inch simulator and every attachment is already 1320 × 2868, the
/// size App Store Connect wants, with no scaling or framing in between.
///
/// It deliberately launches with `-VergUITest` but **without**
/// `-VergSeedData`. That combination skips onboarding and clears the lock
/// without touching `verg.sessions`, so the journal seeded onto the device
/// beforehand — real photographed pages, not the ruled placeholders the test
/// suite draws — survives into the shots.
///
/// Run:
///   xcodebuild test -only-testing:VergUITests/StoreScreenshots \
///     -destination 'id=<a 6.9-inch simulator>'
final class StoreScreenshots: XCTestCase {

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func settle(_ seconds: TimeInterval = 1.4) {
        _ = XCTWaiter.wait(for: [expectation(description: "settle")], timeout: seconds)
    }

    private func open(_ app: XCUIApplication, _ tab: String) {
        let button = app.buttons["tab.\(tab)"]
        guard button.waitForExistence(timeout: 8) else { return }
        button.tap()
        settle()
    }

    func testCaptureStoreScreenshots() throws {
        // Skipped unless asked for. This is a slow capture pass, not a test:
        // it asserts nothing about correctness, it depends on a journal
        // seeded onto the device beforehand, and running it in every suite
        // adds a minute and a failure mode to a run that should only report
        // defects.
        //
        //   VERG_SCREENSHOTS=1 xcodebuild test \
        //     -only-testing:VergUITests/StoreScreenshots \
        //     -destination 'id=<6.9-inch simulator>'
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["VERG_SCREENSHOTS"] == "1",
            "Set VERG_SCREENSHOTS=1 to capture App Store screenshots"
        )

        let app = XCUIApplication()
        // `-VergScreenshots` shows the journal as a subscriber sees it.
        // Without it the grid is mostly padlocks past the free window —
        // the gate working correctly, and the wrong thing to put on a
        // store listing.
        app.launchArguments = ["-VergUITest", "-VergScreenshots", "-VergAppearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.write"].waitForExistence(timeout: 20),
                      "The app never reached the tab bar")
        settle(2.0)

        // 1 — the candle, the run, the invitation.
        open(app, "write")
        shoot(app, "01-write")

        // 2 — the wall of real pages. The argument for the whole app.
        open(app, "journal")
        settle(2.2)
        shoot(app, "02-journal")

        // 3 — one page, full bleed.
        let firstPage = app.scrollViews.buttons.firstMatch
        if firstPage.waitForExistence(timeout: 8) {
            firstPage.tap()
            settle(2.0)
            shoot(app, "03-page")
            // Leave the viewer the way it was opened.
            app.buttons.matching(identifier: "xmark").firstMatch.tap()
            settle()
        }

        // 4 — the record: heatmap, insights, the ladder.
        open(app, "library")
        settle(1.8)
        shoot(app, "04-archive")
        app.swipeUp()
        settle()
        shoot(app, "05-insights")

        // 6 — the candle screen on its own.
        open(app, "verg")
        settle(1.8)
        shoot(app, "06-candle")

        // 7 — the offer.
        open(app, "settings")
        let goldenAge = app.buttons["settings.The Golden Age"]
        if goldenAge.waitForExistence(timeout: 8) {
            goldenAge.tap()
            settle(2.2)
            shoot(app, "07-paywall")
        }
    }
}
