import Foundation
import Combine
import UIKit

/// ViewModel for the Stats screen
final class StatsViewModel: ObservableObject {

    // MARK: - Tab Selection
    enum Tab: String, CaseIterable {
        case pages = "Pages"
        case calendar = "Calendar"
    }

    // MARK: - Published Properties
    @Published var selectedTab: Tab = .pages
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var totalSessions: Int = 0
    @Published private(set) var datesWithSessions: Set<Date> = []
    @Published private(set) var sessionCountsByDate: [Date: Int] = [:]
    @Published var selectedSession: Session?
    @Published var showFullScreenImage: Bool = false
    @Published var currentMonth: Date = Date()

    // MARK: - Dependencies
    private let storageService: StorageService
    private let streakService: StreakService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(
        storageService: StorageService = .shared,
        streakService: StreakService = .shared
    ) {
        self.storageService = storageService
        self.streakService = streakService
        setupBindings()
        // Defer loadData to avoid publishing changes during view updates
        DispatchQueue.main.async { [weak self] in
            self?.loadData()
        }
    }

    // MARK: - Setup
    private func setupBindings() {
        // Listen to sessions changes
        storageService.$sessions
            .receive(on: DispatchQueue.main)
            .assign(to: &$sessions)

        // Listen to stats changes
        storageService.$stats
            .receive(on: DispatchQueue.main)
            .map { $0.currentStreak }
            .assign(to: &$currentStreak)

        storageService.$stats
            .receive(on: DispatchQueue.main)
            .map { $0.totalSessions }
            .assign(to: &$totalSessions)
    }

    // MARK: - Data Loading
    func loadData() {
        sessions = storageService.getAllSessions()
        let stats = storageService.getStats()
        currentStreak = stats.currentStreak
        totalSessions = stats.totalSessions
        datesWithSessions = storageService.getDatesWithSessions()
        sessionCountsByDate = storageService.getSessionCountsByDate()
    }

    func refresh() {
        loadData()
    }

    // MARK: - Image Helpers
    func getImage(for session: Session) -> UIImage? {
        return storageService.getImage(for: session)
    }

    func getImageURL(for session: Session) -> URL {
        return storageService.getImageURL(for: session)
    }

    // MARK: - Actions
    func selectSession(_ session: Session) {
        selectedSession = session
        showFullScreenImage = true
    }

    func deleteSession(_ session: Session) {
        storageService.deleteSession(id: session.id)
        loadData()
    }

    // MARK: - Calendar Helpers
    func previousMonth() {
        currentMonth = currentMonth.addingMonths(-1)
    }

    func nextMonth() {
        currentMonth = currentMonth.addingMonths(1)
    }

    func hasSession(on date: Date) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return datesWithSessions.contains(startOfDay)
    }

    func sessionCount(on date: Date) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return sessionCountsByDate[startOfDay] ?? 0
    }

    func sessionsCount(for month: Date) -> Int {
        streakService.sessions(for: month)
    }

    // MARK: - Stats Helpers
    var streakText: String {
        if currentStreak == 0 {
            return "No streak"
        } else if currentStreak == 1 {
            return "1 day"
        } else {
            return "\(currentStreak) days"
        }
    }

    var isEmpty: Bool {
        sessions.isEmpty
    }
}
