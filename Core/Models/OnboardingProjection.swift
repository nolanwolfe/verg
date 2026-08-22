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
    }

    /// - Parameter daysPerWeek: the commitment chosen during onboarding (3, 5, or 7)
    static func compute(daysPerWeek: Int) -> Result {
        let pages = Int((Double(daysPerWeek) * weeksPerYear).rounded())
        let hours = Double(pages) * minutesPerSession / 60
        return Result(pages: pages, hours: hours)
    }
}
