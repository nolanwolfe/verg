import Foundation

/// Pure, testable logic for the premium "relight" mechanic: The Golden Age
/// subscribers get one relight per rolling 7 days — a missed day doesn't
/// extinguish the candle. Free users' candles go out on any miss.
///
/// A relit day is never counted as a written day (daysLit doesn't
/// increment for it) — it just keeps the candle from resetting to zero.
enum CandleRelight {
    struct Result: Equatable {
        var daysLit: Int
        var relitDates: [Date]
        var candleWentOut: Bool
    }

    /// Walks forward day-by-day from the last session to (but not
    /// including) today. Each gap day is bridged by a relight if the user
    /// is currently premium and hasn't used one in the trailing 7 days;
    /// otherwise the candle goes out and daysLit resets to 0.
    static func evaluate(
        lastSessionDate: Date?,
        daysLit: Int,
        relitDates: [Date],
        isPremium: Bool,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Result {
        guard let lastSessionDate else {
            return Result(daysLit: daysLit, relitDates: relitDates, candleWentOut: false)
        }

        let lastDay = calendar.startOfDay(for: lastSessionDate)
        let todayDay = calendar.startOfDay(for: today)
        guard lastDay < todayDay else {
            return Result(daysLit: daysLit, relitDates: relitDates, candleWentOut: false)
        }

        var relitDates = relitDates
        var cursor = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? todayDay

        while cursor < todayDay {
            if isPremium, isRelightAvailable(asOf: cursor, relitDates: relitDates, calendar: calendar) {
                relitDates.append(cursor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            } else {
                return Result(daysLit: 0, relitDates: relitDates, candleWentOut: true)
            }
        }

        return Result(daysLit: daysLit, relitDates: relitDates, candleWentOut: false)
    }

    /// A relight is available for `day` if no relit date falls within the
    /// 7 days immediately before it. Exactly 7 days after a prior relight
    /// is eligible again (strict lower bound).
    static func isRelightAvailable(asOf day: Date, relitDates: [Date], calendar: Calendar = .current) -> Bool {
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: day) else { return true }
        return !relitDates.contains { $0 > sevenDaysAgo && $0 < day }
    }

    /// Whether `date` was a relit (not written) day — for calendar rendering.
    static func isRelit(_ date: Date, relitDates: [Date], calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return relitDates.contains { calendar.isDate($0, inSameDayAs: day) }
    }
}
