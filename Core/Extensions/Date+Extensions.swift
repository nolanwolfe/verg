import Foundation

extension Date {

    // MARK: - Calendar Helpers

    /// Start of the day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of the day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Start of the month
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// End of the month
    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth) ?? self
    }

    // MARK: - Comparisons

    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    /// Check if date is in this week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Check if date is in this month
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    /// Check if date is in this year
    var isThisYear: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }

    /// Check if same day as another date
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    // MARK: - Components

    /// Day of month (1-31)
    var day: Int {
        Calendar.current.component(.day, from: self)
    }

    /// Month (1-12)
    var month: Int {
        Calendar.current.component(.month, from: self)
    }

    /// Year
    var year: Int {
        Calendar.current.component(.year, from: self)
    }

    /// Weekday (1 = Sunday, 7 = Saturday)
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }

    /// Hour (0-23)
    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }

    /// Minute (0-59)
    var minute: Int {
        Calendar.current.component(.minute, from: self)
    }

    // MARK: - Date Arithmetic

    /// Add days to date
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Add months to date
    func addingMonths(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }

    /// Days between two dates
    func days(to date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: self.startOfDay, to: date.startOfDay).day ?? 0
    }

    // MARK: - Calendar Generation

    /// Get all days in the month
    var daysInMonth: [Date] {
        let range = Calendar.current.range(of: .day, in: .month, for: self)!
        return range.compactMap { day -> Date? in
            var components = Calendar.current.dateComponents([.year, .month], from: self)
            components.day = day
            return Calendar.current.date(from: components)
        }
    }

    /// Number of days in the month
    var numberOfDaysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: self)?.count ?? 30
    }

    /// First weekday of the month (0 = Sunday for US locale)
    var firstWeekdayOfMonth: Int {
        let firstDay = startOfMonth
        return Calendar.current.component(.weekday, from: firstDay) - 1
    }

    // MARK: - Formatting

    /// Formatted as "January 2024"
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }

    /// Formatted as "Jan"
    var shortMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: self)
    }

    /// Formatted as "Mon"
    var shortWeekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }

    /// Formatted as "Monday"
    var weekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }

    /// Formatted as "8:00 PM"
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Formatted as "Jan 15, 2024"
    var mediumDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// Relative date string ("Today", "Yesterday", or date)
    var relativeDateString: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            return mediumDateString
        }
    }
}
