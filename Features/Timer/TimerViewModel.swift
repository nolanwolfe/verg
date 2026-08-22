import Foundation
import Combine
import UIKit

/// ViewModel for the Timer screen
final class TimerViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var timeRemaining: TimeInterval = 0
    @Published private(set) var totalDuration: TimeInterval = 0
    @Published private(set) var activeDuration: TimeInterval = 0
    @Published private(set) var progress: Double = 1.0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isComplete: Bool = false
    @Published var showCamera: Bool = false
    @Published var showUploadPhotoNotice: Bool = false
    @Published var celebratedMilestone: Milestone?
    @Published var timeReclaimedMoment: TimeReclaimedMoment?

    // MARK: - Dependencies
    private let timerService: TimerService
    private let audioService: AudioService
    private let storageService: StorageService
    private let purchaseService: PurchaseService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks
    /// Called when the session screen should close. Passes the Session that
    /// was saved (photo captured), or nil if it was skipped/cancelled before
    /// a page was saved — HomeView uses this to decide whether to show the
    /// "Time Reclaimed" confirmation.
    var onComplete: ((Session?) -> Void)?

    // MARK: - Computed Properties
    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Initialization
    init(
        timerService: TimerService = TimerService(),
        audioService: AudioService = .shared,
        storageService: StorageService = .shared,
        purchaseService: PurchaseService = .shared
    ) {
        self.timerService = timerService
        self.audioService = audioService
        self.storageService = storageService
        self.purchaseService = purchaseService
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        timerService.$timeRemaining
            .receive(on: DispatchQueue.main)
            .assign(to: &$timeRemaining)

        timerService.$totalDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$totalDuration)

        timerService.$activeDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$activeDuration)

        timerService.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRunning)

        timerService.$isComplete
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isComplete in
                self?.isComplete = isComplete
                if isComplete {
                    self?.handleTimerComplete()
                }
            }
            .store(in: &cancellables)

        // Update progress
        timerService.$timeRemaining
            .combineLatest(timerService.$totalDuration)
            .map { remaining, total -> Double in
                guard total > 0 else { return 1.0 }
                return remaining / total
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$progress)
    }

    // MARK: - Actions
    func startTimer(duration: TimeInterval? = nil) {
        let duration = duration ?? storageService.settings.timerDuration

        // Play start bell if sound enabled
        if storageService.settings.soundEnabled {
            audioService.playStartBell()
        }

        // Start timer — publishes totalDuration/timeRemaining via Combine pipeline
        timerService.start(duration: duration)

        // Ambient sound during the session (Pro)
        startAmbienceIfEnabled()
    }

    func stopTimer() {
        noticeWorkItem?.cancel()
        audioService.stopAmbience()
        timerService.stopTimer()
    }

    func cancelSession() {
        noticeWorkItem?.cancel()
        audioService.stopAmbience()
        timerService.stopTimer()
        onComplete?(nil)
    }

    /// Start looping ambience if the option is on and the user is Pro.
    /// Always called on the main thread (view-driven).
    private func startAmbienceIfEnabled() {
        guard storageService.settings.ambientSoundEnabled,
              let sound = AudioService.AmbientSound(rawValue: storageService.settings.ambientSoundID) else {
            return
        }
        let isPremium = MainActor.assumeIsolated { SessionGatingService.shared.isPremium }
        guard isPremium else { return }
        audioService.startAmbience(sound)
    }

    // MARK: - Private Methods
    private var noticeWorkItem: DispatchWorkItem?

    private func handleTimerComplete() {
        // Fade the ambience out as the bell rings
        audioService.stopAmbience()

        // Play end bell if sound enabled
        if storageService.settings.soundEnabled {
            audioService.playEndBell()
        }

        // Play haptic
        audioService.playHaptic(UINotificationFeedbackGenerator.FeedbackType.success)

        // Always show "Save your page" notice after session completes
        // This prompts user to upload a photo of their writing
        // Delay matches burnout sequence duration: stutter (0.5s) + extinguish (0.22s) + margin
        noticeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.showUploadPhotoNotice = true
        }
        noticeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }

    // MARK: - Upload Photo Notice Handlers

    /// Called when user taps "Upload photo" on the coach mark notice
    func onUploadPhotoTapped() {
        showUploadPhotoNotice = false
        showCamera = true
    }

    /// Called when user taps "+5 more minutes" on the coach mark notice
    func onAddFiveMinutesTapped() {
        showUploadPhotoNotice = false
        audioService.playImpact(.medium)
        timerService.addTime(300)
        startAmbienceIfEnabled()
    }

    /// Called when user taps "Skip" on the coach mark notice
    func onSkipPhotoTapped() {
        showUploadPhotoNotice = false
        // Session completes without saving a photo
        onComplete?(nil)
    }

    /// The just-saved session, held between `onPhotoSaved` and the eventual
    /// `onComplete` call so a milestone celebration and the Time Reclaimed
    /// reveal can sit in between without losing track of what to report.
    private var pendingSession: Session?

    func onPhotoSaved(_ session: Session) {
        showCamera = false
        pendingSession = session

        // Session saved - log for debugging
        let sessionCount = storageService.sessions.count
        #if DEBUG
        print("[SessionGating] Photo saved. Total sessions: \(sessionCount)")
        #endif

        // Crossed a page milestone? Celebrate before the Time Reclaimed reveal.
        if let milestone = AchievementService.shared.checkForNewMilestones(
            totalSessions: storageService.stats.totalSessions
        ) {
            celebratedMilestone = milestone
            return
        }

        presentTimeReclaimedMoment(for: session)
    }

    /// Called when the milestone celebration is dismissed
    func dismissCelebration() {
        celebratedMilestone = nil
        guard let session = pendingSession else {
            onComplete?(nil)
            return
        }
        presentTimeReclaimedMoment(for: session)
    }

    /// Builds the post-session reveal from today's sessions (including the
    /// one just saved). Uses the running daily total — not just this
    /// session's length — once a second session lands the same day, per
    /// the "no per-session repeats" rule.
    private func presentTimeReclaimedMoment(for session: Session) {
        let calendar = Calendar.current
        let todaysSessions = storageService.sessions.filter { calendar.isDateInToday($0.date) }
        let isFirstSessionToday = todaysSessions.count <= 1
        let todaySeconds = todaysSessions.reduce(0) { $0 + $1.activeDuration }
        timeReclaimedMoment = TimeReclaimed.moment(
            todaySeconds: todaySeconds,
            isFirstSessionToday: isFirstSessionToday,
            streak: storageService.stats.currentStreak
        )
    }

    /// Called when the Time Reclaimed reveal is dismissed — the last step
    /// before the session screen closes.
    func dismissTimeReclaimed() {
        timeReclaimedMoment = nil
        onComplete?(pendingSession)
    }

}
