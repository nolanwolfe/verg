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

        /// The closing line, e.g. "43 hours that belong to you."
        ///
        /// Repeats the hours deliberately. The block above says what the
        /// time is taken *from* — hours off your phone — and this says whose
        /// they are; saying the number twice is what turns a subtraction
        /// into a gain. It used to spell out the page count instead, which
        /// restated the stat directly above it and made the same point twice
        /// rather than the second point once.
        ///
        /// Computed, never fixed: three days a week is not 260 pages.
        var closingLine: String {
            "\(formattedHours) that belong to you."
        }
    }

    /// - Parameter daysPerWeek: the commitment chosen during onboarding (3, 5, or 7)
    static func compute(daysPerWeek: Int) -> Result {
        let pages = Int((Double(daysPerWeek) * weeksPerYear).rounded())
        let hours = Double(pages) * minutesPerSession / 60
        return Result(pages: pages, hours: hours)
    }
}
