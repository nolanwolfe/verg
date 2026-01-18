import SwiftUI

/// Calendar view showing writing activity
struct CalendarView: View {
    @Binding var currentMonth: Date
    let sessionCountsByDate: [Date: Int]
    let currentStreak: Int
    let totalSessions: Int
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Spacing.lg) {
                // Stats cards
                statsSection

                // Calendar
                calendarSection
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            StatCard(
                title: "Current Streak",
                value: "\(currentStreak)",
                unit: currentStreak == 1 ? "day" : "days",
                icon: "flame.fill",
                iconColor: Color.orange
            )

            StatCard(
                title: "Total Sessions",
                value: "\(totalSessions)",
                unit: totalSessions == 1 ? "page" : "pages",
                icon: "doc.text.fill",
                iconColor: Theme.Colors.accent
            )
        }
    }

    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Month navigation
            monthHeader

            // Weekday headers
            weekdayHeader

            // Calendar grid
            calendarGrid
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
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
                    .frame(width: 44, height: 44)
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
                    .frame(width: 44, height: 44)
            }
            .disabled(Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month))
            .opacity(Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month) ? 0.3 : 1)
        }
    }

    // MARK: - Weekday Header
    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.xxs) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .frame(height: 30)
            }
        }
    }

    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        let days = generateDaysInMonth()

        return LazyVGrid(columns: columns, spacing: Theme.Spacing.xxs) {
            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
                    DayCell(
                        date: date,
                        sessionCount: sessionCount(on: date),
                        isToday: Calendar.current.isDateInToday(date),
                        isCurrentMonth: true
                    )
                } else {
                    // Empty cell for padding
                    Color.clear
                        .frame(height: 40)
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

    private var hasSession: Bool {
        sessionCount > 0
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Text("\(date.day)")
                    .font(Theme.Typography.body)
                    .foregroundColor(textColor)
                    .frame(width: 36, height: 36)
                    .background(backgroundColor)
                    .clipShape(Circle())

                // Badge for multiple sessions
                if sessionCount > 1 {
                    Text("\(sessionCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.Colors.background)
                        .frame(width: 14, height: 14)
                        .background(Theme.Colors.accent)
                        .clipShape(Circle())
                        .offset(x: 4, y: -2)
                }
            }

            // Session indicator dot
            Circle()
                .fill(hasSession ? Theme.Colors.accent : Color.clear)
                .frame(width: 6, height: 6)
        }
        .frame(height: 50)
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
            currentStreak: 5,
            totalSessions: 12,
            onPreviousMonth: {},
            onNextMonth: {}
        )
    }
}
