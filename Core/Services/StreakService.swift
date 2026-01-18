import Foundation
import Combine

/// Service for managing streak calculations and validation
final class StreakService: ObservableObject {

    // MARK: - Singleton
    static let shared = StreakService()

    // MARK: - Dependencies
    private let storage: StorageService

    // MARK: - Published Properties
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var hasWrittenToday: Bool = false

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init(storage: StorageService = .shared) {
        self.storage = storage
        setupBindings()
        refreshStreak()
    }

    // MARK: - Setup
    private func setupBindings() {
        // Listen to stats changes
        storage.$stats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.currentStreak = stats.currentStreak
                self?.longestStreak = stats.longestStreak
                self?.hasWrittenToday = stats.hasWrittenToday
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods
    /// Refresh and validate streak on app launch
    func refreshStreak() {
        var stats = storage.getStats()
        stats.validateStreak()
        storage.updateStats(stats)

        currentStreak = stats.currentStreak
        longestStreak = stats.longestStreak
        hasWrittenToday = stats.hasWrittenToday
    }

    /// Record a completed session
    func recordSession() {
        var stats = storage.getStats()
        stats.recordSession()
        storage.updateStats(stats)

        currentStreak = stats.currentStreak
        longestStreak = stats.longestStreak
        hasWrittenToday = stats.hasWrittenToday
    }

    /// Get streak text for display
    var streakText: String {
        if currentStreak == 0 {
            return "Start your streak!"
        } else if currentStreak == 1 {
            return "1 day streak"
        } else {
            return "\(currentStreak) day streak"
        }
    }

    /// Get formatted streak with emoji
    var streakDisplayText: String {
        if currentStreak == 0 {
            return "Start your streak today!"
        } else {
            return "\u{1F525} \(streakText)"  // Fire emoji
        }
    }

    /// Check if streak will break tomorrow if user doesn't write
    var streakAtRisk: Bool {
        hasWrittenToday == false && currentStreak > 0
    }

    /// Days until streak breaks
    var daysUntilStreakBreaks: Int {
        if hasWrittenToday {
            return 2 // Today done, have all of tomorrow plus grace
        } else {
            return 1 // Need to write today
        }
    }

    // MARK: - Analytics Helpers
    /// Average sessions per week based on total sessions and first session date
    func averageSessionsPerWeek() -> Double {
        let sessions = storage.getAllSessions()
        guard let firstSession = sessions.last,
              sessions.count > 1 else {
            return 0
        }

        let daysSinceFirst = Calendar.current.dateComponents(
            [.day],
            from: firstSession.date,
            to: Date()
        ).day ?? 1

        let weeks = max(Double(daysSinceFirst) / 7.0, 1.0)
        return Double(sessions.count) / weeks
    }

    /// Get the current month's session count
    func sessionsThisMonth() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let sessions = storage.getAllSessions()

        return sessions.filter { session in
            calendar.isDate(session.date, equalTo: now, toGranularity: .month)
        }.count
    }

    /// Get sessions for a specific month
    func sessions(for month: Date) -> Int {
        let calendar = Calendar.current
        let sessions = storage.getAllSessions()

        return sessions.filter { session in
            calendar.isDate(session.date, equalTo: month, toGranularity: .month)
        }.count
    }
}
