import SwiftUI

/// Calendar view showing writing activity
struct CalendarView: View {
    @Binding var currentMonth: Date
    let sessionCountsByDate: [Date: Int]
    /// Days bridged by a premium relight rather than written — rendered
    /// visually distinct from both written and missed days, never as if
    /// the user actually wrote.
    var relitDates: Set<Date> = []
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    /// Shrinks cell size, spacing, and padding to fit a single
    /// non-scrolling screen on smaller devices. Never hides a row —
    /// every day in the month always renders.
    var compact: Bool = false

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        calendarSection
    }

    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(spacing: compact ? Theme.Spacing.xs : Theme.Spacing.sm) {
            // Month navigation
            monthHeader

            // Weekday headers
            weekdayHeader

            // Calendar grid
            calendarGrid
        }
        .padding(compact ? Theme.Spacing.sm : Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
    }

    // MARK: - Month Header
    private var monthHeader: some View {
        HStack {
            Button {
                onPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(width: 44, height: compact ? 32 : 44)
            }

            Spacer()

            Text(currentMonth.monthYearString)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.primaryText)

            Spacer()

            Button {
                onNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(width: 44, height: compact ? 32 : 44)
            }
            .disabled(Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month))
            .opacity(Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month) ? 0.3 : 1)
        }
    }

    // MARK: - Weekday Header
    private var weekdayHeader: some View {
        // Index-based identity, not \.self — "S" and "T" each appear
        // twice in weekdays, and ForEach(id: \.self) silently drops
        // duplicate-value views rather than rendering all seven.
        LazyVGrid(columns: columns, spacing: Theme.Spacing.xxs) {
            ForEach(weekdays.indices, id: \.self) { index in
                Text(weekdays[index])
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(height: compact ? 18 : 30)
            }
        }
    }

    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        let days = generateDaysInMonth()
        let cellHeight: CGFloat = compact ? 34 : 50

        return LazyVGrid(columns: columns, spacing: compact ? 2 : Theme.Spacing.xxs) {
            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
                    DayCell(
                        date: date,
                        sessionCount: sessionCount(on: date),
                        isToday: Calendar.current.isDateInToday(date),
                        isCurrentMonth: true,
                        isRelit: relitDates.contains(Calendar.current.startOfDay(for: date)),
                        compact: compact
                    )
                } else {
                    // Empty cell for padding
                    Color.clear
                        .frame(height: cellHeight)
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func generateDaysInMonth() -> [Date?] {
        let calendar = Calendar.current

        // Get first day of month
        let firstDayOfMonth = currentMonth.startOfMonth

        // Get number of days in month
        let daysInMonth = currentMonth.numberOfDaysInMonth

        // Get weekday of first day (0 = Sunday)
        let firstWeekday = currentMonth.firstWeekdayOfMonth

        // Create array with leading empty cells
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        // Add all days
        for day in 1...daysInMonth {
            var components = calendar.dateComponents([.year, .month], from: firstDayOfMonth)
            components.day = day
            if let date = calendar.date(from: components) {
                days.append(date)
            }
        }

        return days
    }

    private func sessionCount(on date: Date) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return sessionCountsByDate[startOfDay] ?? 0
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 16))

                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxxs) {
                Text(value)
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.primaryText)

                Text(unit)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let sessionCount: Int
    let isToday: Bool
    let isCurrentMonth: Bool
    var isRelit: Bool = false
    var compact: Bool = false

    private var hasSession: Bool {
        sessionCount > 0
    }

    private var circleSize: CGFloat { compact ? 26 : 36 }

    var body: some View {
        VStack(spacing: compact ? 1 : 2) {
            ZStack(alignment: .topTrailing) {
                Text("\(date.day)")
                    .font(compact ? Theme.Typography.footnote : Theme.Typography.body)
                    .foregroundColor(textColor)
                    .frame(width: circleSize, height: circleSize)
                    .background(backgroundColor)
                    .clipShape(Circle())

                // Badge for multiple sessions
                if sessionCount > 1 {
                    Text("\(sessionCount)")
                        .font(.system(size: compact ? 8 : 9, weight: .bold))
                        .foregroundColor(Theme.Colors.background)
                        .frame(width: compact ? 12 : 14, height: compact ? 12 : 14)
                        .background(Theme.Colors.accent)
                        .clipShape(Circle())
                        .offset(x: 3, y: -1)
                }
            }

            // Day indicator: solid dot = written, ringed amber dot = relit
            // (bridged, not written), nothing = missed. Never render a relit
            // day as if it were written.
            if hasSession {
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 6, height: 6)
            } else if isRelit {
                Circle()
                    .strokeBorder(Theme.Colors.flameOuter, lineWidth: 1.5)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: compact ? 34 : 50)
    }

    private var textColor: Color {
        if isToday {
            return Theme.Colors.primaryText
        } else if hasSession {
            return Theme.Colors.primaryText
        } else {
            return Theme.Colors.secondaryText
        }
    }

    private var backgroundColor: Color {
        if isToday {
            return Theme.Colors.accent.opacity(0.3)
        }
        return Color.clear
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        CalendarView(
            currentMonth: .constant(Date()),
            sessionCountsByDate: [Date().startOfDay: 2],
            onPreviousMonth: {},
            onNextMonth: {}
        )
    }
}
