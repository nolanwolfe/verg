import Foundation
import Combine
import UIKit

/// ViewModel for the Stats screen
final class StatsViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var currentSessions: [Session] = []
    @Published private(set) var books: [Book] = []
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var totalSessions: Int = 0
    @Published private(set) var datesWithSessions: Set<Date> = []
    @Published private(set) var sessionCountsByDate: [Date: Int] = [:]
    @Published private(set) var timeReclaimed: TimeReclaimedSummary = .zero
    @Published var selectedSession: Session?
    @Published var selectedSessionIndex: Int = 0
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

        // Current journal = sessions not archived into a book
        storageService.$sessions
            .combineLatest(storageService.$books)
            .receive(on: DispatchQueue.main)
            .map { sessions, books in
                Book.currentSessions(from: sessions, books: books)
            }
            .assign(to: &$currentSessions)

        storageService.$books
            .receive(on: DispatchQueue.main)
            .assign(to: &$books)

        // Listen to stats changes
        storageService.$stats
            .receive(on: DispatchQueue.main)
            .map { $0.currentStreak }
            .assign(to: &$currentStreak)

        storageService.$stats
            .receive(on: DispatchQueue.main)
            .map { $0.totalSessions }
            .assign(to: &$totalSessions)

        storageService.$stats
            .receive(on: DispatchQueue.main)
            .map { $0.longestStreak }
            .assign(to: &$longestStreak)
    }

    // MARK: - Data Loading
    func loadData() {
        sessions = storageService.getAllSessions()
        currentSessions = storageService.currentSessions
        books = storageService.books
        let stats = storageService.getStats()
        currentStreak = stats.currentStreak
        longestStreak = stats.longestStreak
        totalSessions = stats.totalSessions
        datesWithSessions = storageService.getDatesWithSessions()
        sessionCountsByDate = storageService.getSessionCountsByDate()
        timeReclaimed = storageService.timeReclaimedSummary()
    }

    func refresh() {
        loadData()
    }

    // MARK: - Image Helpers
    func getImage(for session: Session) -> UIImage? {
        return storageService.getImage(for: session)
    }

    func getThumbnail(for session: Session) -> UIImage? {
        return storageService.getThumbnail(for: session)
    }

    func loadImageAsync(for session: Session) async -> UIImage? {
        await storageService.loadImageAsync(for: session)
    }

    func loadThumbnailAsync(for session: Session) async -> UIImage? {
        await storageService.loadThumbnailAsync(for: session)
    }

    /// Cache-only synchronous lookup, safe on the main thread
    func cachedThumbnail(for session: Session) -> UIImage? {
        storageService.cachedThumbnail(for: session)
    }

    func getImageURL(for session: Session) -> URL {
        return storageService.getImageURL(for: session)
    }

    // MARK: - Actions
    func selectSession(_ session: Session) {
        selectSession(session, in: sessions)
    }

    /// Select a session for fullscreen viewing within a specific list
    /// (e.g. the current journal, which excludes archived pages)
    func selectSession(_ session: Session, in list: [Session]) {
        selectedSession = session
        selectedSessionIndex = list.firstIndex(where: { $0.id == session.id }) ?? 0
        showFullScreenImage = true
    }

    // MARK: - Books
    /// Archive the current journal as a book; returns true on success
    @discardableResult
    func finishCurrentJournal(title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmed.isEmpty ? "Journal \(storageService.books.count + 1)" : trimmed
        let book = storageService.finishCurrentJournal(title: finalTitle)
        loadData()
        return book != nil
    }

    func deleteBook(_ book: Book) {
        storageService.deleteBook(id: book.id)
        loadData()
    }

    func sessions(for book: Book) -> [Session] {
        storageService.sessions(for: book)
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
