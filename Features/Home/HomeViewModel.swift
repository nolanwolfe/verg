import Foundation
import Combine

/// ViewModel for the Home screen
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var hasWrittenToday: Bool = false
    @Published private(set) var sessionsToday: Int = 0
    @Published var showTimer: Bool = false

    // MARK: - Dependencies
    private let streakService: StreakService
    private let storageService: StorageService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var streakText: String {
        if currentStreak == 0 {
            return "Start your streak today!"
        } else if currentStreak == 1 {
            return "1 day streak"
        } else {
            return "\(currentStreak) day streak"
        }
    }

    var streakDisplayText: String {
        if currentStreak > 0 {
            return "\u{1F525} \(streakText)"
        }
        return streakText
    }

    var sessionsTodayText: String {
        if sessionsToday == 0 {
            return "Start your first session today!"
        } else if sessionsToday == 1 {
            return "1 session today"
        } else {
            return "\(sessionsToday) sessions today"
        }
    }

    var buttonText: String {
        "Begin Writing"
    }

    var canStartSession: Bool {
        true
    }

    // MARK: - Initialization
    init(
        streakService: StreakService = .shared,
        storageService: StorageService = .shared
    ) {
        self.streakService = streakService
        self.storageService = storageService
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        // Observe streak changes
        streakService.$currentStreak
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentStreak)

        streakService.$hasWrittenToday
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasWrittenToday)
    }

    // MARK: - Actions
    func refresh() {
        streakService.refreshStreak()
        updateSessionsToday()
    }

    private func updateSessionsToday() {
        let todaySessions = storageService.getSessions(for: Date())
        sessionsToday = todaySessions.count
    }

    func startWriting() {
        showTimer = true
    }

    func onSessionComplete() {
        showTimer = false
        refresh()
    }
}
