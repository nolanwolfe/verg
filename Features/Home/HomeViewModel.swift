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
        AppStrings.Home.daysLitText(daysLit: daysLit, longestDaysLit: candleService.longestDaysLit)
    }

    var daysLitDisplayText: String {
        daysLitText
    }

    /// Whether the candle graphic itself should render unlit. Drives
    /// CandleView's relight animation in HomeView once a session brings
    /// `daysLit` back above zero.
    var candleWentOut: Bool {
        candleService.candleWentOut
    }

    var sessionsTodayText: String {
        AppStrings.Home.sessionsTodayText(sessionsToday)
    }

    var buttonText: String {
        AppStrings.Home.beginWriting
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
