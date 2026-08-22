import Foundation
import Combine

/// ViewModel for the Home screen
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var daysLit: Int = 0
    @Published private(set) var hasWrittenToday: Bool = false
    @Published private(set) var sessionsToday: Int = 0

    // MARK: - Dependencies
    private let candleService: CandleService
    private let storageService: StorageService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var daysLitText: String {
        if daysLit == 0 {
            return "Light your candle today!"
        } else if daysLit == 1 {
            return "1 day lit"
        } else {
            return "\(daysLit) days lit"
        }
    }

    var daysLitDisplayText: String {
        daysLitText
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
        candleService: CandleService = .shared,
        storageService: StorageService = .shared
    ) {
        self.candleService = candleService
        self.storageService = storageService
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        // Observe days-lit changes
        candleService.$daysLit
            .receive(on: DispatchQueue.main)
            .assign(to: &$daysLit)

        candleService.$hasWrittenToday
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasWrittenToday)
    }

    // MARK: - Actions
    func refresh() {
        candleService.refreshDaysLit()
        updateSessionsToday()
    }

    private func updateSessionsToday() {
        let todaySessions = storageService.getSessions(for: Date())
        sessionsToday = todaySessions.count
    }

    func onSessionComplete() {
        refresh()
    }
}
