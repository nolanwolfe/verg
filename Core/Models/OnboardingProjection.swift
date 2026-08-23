import Foundation

/// Honest, computed arithmetic for the onboarding projection screen — never
/// hardcoded per frequency. Assumes the app's own pitch: one page per
/// session, `AppSettings.defaultTimerDuration` minutes per session, 52
/// weeks a year.
enum OnboardingProjection {
    static let weeksPerYear: Double = 52
    static let minutesPerSession: Double = AppSettings.defaultTimerDuration / 60

    struct Result: Equatable {
        let pages: Int
        let hours: Double

        /// e.g. "43 hours" — rounded to the nearest whole hour, since
        /// fractional hours read as false precision on a projection.
        var formattedHours: String {
            let rounded = Int(hours.rounded())
            return "\(rounded) \(rounded == 1 ? "hour" : "hours")"
        }

        /// The closing line, e.g. "Two hundred sixty pages you can hold."
        /// Spelled out rather than repeating the numeral already shown
        /// above it, and computed from the chosen pace — 3 days a week is
        /// not 260 pages, so this can't be a fixed string.
        var closingLine: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .spellOut
            let words = formatter.string(from: NSNumber(value: pages)) ?? "\(pages)"
            let capitalised = words.prefix(1).uppercased() + words.dropFirst()
            return "\(capitalised) \(pages == 1 ? "page" : "pages") you can hold."
        }
    }

    /// - Parameter daysPerWeek: the commitment chosen during onboarding (3, 5, or 7)
    static func compute(daysPerWeek: Int) -> Result {
        let pages = Int((Double(daysPerWeek) * weeksPerYear).rounded())
        let hours = Double(pages) * minutesPerSession / 60
        return Result(pages: pages, hours: hours)
    }
}
