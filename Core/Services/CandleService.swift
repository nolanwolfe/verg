import Foundation
import Combine

/// Owns the candle's "days lit" count and the premium relight mechanic —
/// formerly StreakService, renamed along with the streak -> days-lit
/// language change throughout the app.
final class CandleService: ObservableObject {

    // MARK: - Singleton
    static let shared = CandleService()

    // MARK: - Dependencies
    private let storage: StorageService
    private let purchaseService: PurchaseService

    // MARK: - Published Properties
    @Published private(set) var daysLit: Int = 0
    @Published private(set) var longestDaysLit: Int = 0
    @Published private(set) var hasWrittenToday: Bool = false
    @Published private(set) var relitDates: [Date] = []

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init(storage: StorageService = .shared, purchaseService: PurchaseService = .shared) {
        self.storage = storage
        self.purchaseService = purchaseService
        setupBindings()
        refreshDaysLit()
    }

    // MARK: - Setup
    private func setupBindings() {
        storage.$stats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.daysLit = stats.daysLit
                self?.longestDaysLit = stats.longestDaysLit
                self?.hasWrittenToday = stats.hasWrittenToday
                self?.relitDates = stats.relitDates
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Re-evaluate the candle on app launch (or whenever premium status
    /// might have changed) — walks any gap since the last session, bridging
    /// with relights where the user is premium and one's available, or
    /// resetting to zero where it isn't.
    func refreshDaysLit() {
        var stats = storage.getStats()
        let isPremium = MainActor.assumeIsolated {
            purchaseService.isSubscribed || purchaseService.isFriendsAndFamily
        }

        let result = CandleRelight.evaluate(
            lastSessionDate: stats.lastSessionDate,
            daysLit: stats.daysLit,
            relitDates: stats.relitDates,
            isPremium: isPremium
        )
        stats.daysLit = result.daysLit
        stats.relitDates = result.relitDates
        storage.updateStats(stats)

        daysLit = stats.daysLit
        longestDaysLit = stats.longestDaysLit
        hasWrittenToday = stats.hasWrittenToday
        relitDates = stats.relitDates
    }

    /// Record a completed session
    func recordSession() {
        var stats = storage.getStats()
        stats.recordSession()
        storage.updateStats(stats)

        daysLit = stats.daysLit
        longestDaysLit = stats.longestDaysLit
        hasWrittenToday = stats.hasWrittenToday
    }

    /// Whether `date` was bridged by a relight rather than written —
    /// drives the calendar's third, visually-distinct day state.
    func isRelit(_ date: Date) -> Bool {
        CandleRelight.isRelit(date, relitDates: relitDates)
    }

    /// Get days-lit text for display
    var daysLitText: String {
        AppStrings.Home.daysLitText(daysLit: daysLit, longestDaysLit: longestDaysLit)
    }

    /// Get formatted days-lit text (pair with CandleFlameIcon in the UI)
    var daysLitDisplayText: String {
        daysLitText
    }

    /// Check if the candle is at risk of going out tomorrow
    var candleAtRisk: Bool {
        hasWrittenToday == false && daysLit > 0
    }

    /// Days until the candle goes out
    var daysUntilCandleGoesOut: Int {
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
