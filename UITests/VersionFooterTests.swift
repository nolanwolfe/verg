import XCTest

/// The version string in the Settings footer.
///
/// Worth a test because the string is assembled from build settings and a
/// receipt check, and every input is invisible from the code: the receipt
/// filename differs between the store, TestFlight and the simulator, and
/// getting it wrong fails silently — the footer still shows *a* version,
/// just the wrong one. The first attempt at this shipped exactly that bug,
/// reporting the simulator as a released build.
final class VersionFooterTests: XCTestCase {

    func testFooterShowsThePaddedBuildOutsideTheAppStore() {
        let app = XCUIApplication()
        app.launchArguments = ["-VergUITest", "-VergAppearance", "light"]
        app.launch()

        let settings = app.buttons["tab.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20), "never reached the tab bar")
        settings.tap()
        _ = XCTWaiter.wait(for: [expectation(description: "settle")], timeout: 2.0)

        // The footer is the last thing in a long scroll view.
        for _ in 0..<8 { app.swipeUp() }
        _ = XCTWaiter.wait(for: [expectation(description: "settle")], timeout: 1.5)

        let shown = app.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .first { $0.hasPrefix("Version ") }

        guard let shown else {
            return XCTFail("No version string in the Settings footer")
        }

        // This runs in the simulator, which must never be taken for a
        // released build — so the build number has to be present, and
        // padded to three digits.
        let pattern = #"^Version \d+\.\d+\.\d{3}$"#
        XCTAssertNotNil(
            shown.range(of: pattern, options: .regularExpression),
            """
            Footer read "\(shown)". Outside the App Store it should carry \
            the zero-padded build, as in "Version 2.2.043" — a bare \
            "Version 2.2" means the receipt check has taken this build for \
            a released one.
            """
        )
    }
}
