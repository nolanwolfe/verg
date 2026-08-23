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
    @Published var celebratedGoalMilestone: WeeklyGoalMilestone?
    @Published var timeReclaimedMoment: TimeReclaimedMoment?
    /// A crossed terrace's one line of text — quiet, non-blocking, shown
    /// as a small banner rather than a full-screen celebration.
    @Published var terraceMessage: String?

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

        // Impact as the candle catches — the ritual's tactile beat
        audioService.playImpact(.medium)

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

    /// Pause the countdown in place (distinct from cancelling the session);
    /// resume continues from the same time remaining.
    func pauseTimer() {
        audioService.playImpact(.light)
        audioService.stopAmbience(fadeOut: 0.3)
        timerService.pause()
    }

    func resumeTimer() {
        audioService.playImpact(.light)
        timerService.resume()
        startAmbienceIfEnabled()
    }

    // MARK: - Ambience (Pro)
    var ambientSoundEnabled: Bool { storageService.settings.ambientSoundEnabled }
    var ambientSoundID: String { storageService.settings.ambientSoundID }

    /// Quick mute/unmute of the current ambience — persists like the
    /// Settings toggle does, so it stays off/on next session too.
    func toggleAmbienceMuted() {
        setAmbienceEnabled(!ambientSoundEnabled)
    }

    func setAmbienceEnabled(_ enabled: Bool) {
        audioService.playImpact(.light)
        storageService.setAmbientSoundEnabled(enabled)
        objectWillChange.send()
        if enabled {
            startAmbienceIfEnabled()
        } else {
            audioService.stopAmbience(fadeOut: 0.3)
        }
    }

    /// Choosing a sound also turns ambience on — picking one is the intent.
    func selectAmbientSound(_ sound: AudioService.AmbientSound) {
        audioService.playImpact(.light)
        storageService.setAmbientSoundID(sound.rawValue)
        storageService.setAmbientSoundEnabled(true)
        objectWillChange.send()
        if isRunning {
            audioService.startAmbience(sound)
        }
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

        // Day 3 of a lit candle, right after the bell — one of exactly
        // two places this ever fires (the other is onboarding). Never on
        // cold launch, never twice a session (RatingPromptService enforces
        // that itself).
        if storageService.stats.daysLit == 3 {
            MainActor.assumeIsolated {
                RatingPromptService.requestReviewIfAppropriate()
            }
        }

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
    /// `onComplete` call so the celebration sequence and the Time Reclaimed
    /// reveal can sit in between without losing track of what to report.
    private var pendingSession: Session?
    /// A crossed weekly-goal milestone, queued behind the page-milestone
    /// celebration (if any) so at most one celebration shows at a time.
    private var pendingGoalMilestone: WeeklyGoalMilestone?

    func onPhotoSaved(_ session: Session) {
        showCamera = false
        pendingSession = session

        // Session saved - log for debugging
        let sessionCount = storageService.sessions.count
        #if DEBUG
        print("[SessionGating] Photo saved. Total sessions: \(sessionCount)")
        #endif

        // Seven terraces — quiet, no full-screen takeover. Just a marked
        // day (calendar, handled elsewhere) and one line of text here.
        // Independent of the celebration sequence below; never blocks it.
        if let terrace = AchievementService.shared.checkForNewTerraces(daysLit: storageService.stats.daysLit) {
            terraceMessage = terrace.title
        }

        // Compute a goal-milestone crossing now (if the user set a weekly
        // commitment during onboarding), but queue it — page milestones
        // take celebration priority when both land on the same save.
        if let goalDaysPerWeek = storageService.settings.weeklyCommitmentDaysPerWeek {
            pendingGoalMilestone = AchievementService.shared.checkForNewWeeklyGoalMilestones(
                sessions: storageService.sessions,
                goalDaysPerWeek: goalDaysPerWeek
            )
        }

        // Crossed a page milestone? Celebrate before anything else.
        if let milestone = AchievementService.shared.checkForNewMilestones(
            totalSessions: storageService.stats.totalSessions
        ) {
            audioService.playHaptic(UINotificationFeedbackGenerator.FeedbackType.success)
            celebratedMilestone = milestone
            return
        }

        presentNextCelebrationOrTimeReclaimed(for: session)
    }

    /// Called when the page-milestone celebration is dismissed
    func dismissCelebration() {
        celebratedMilestone = nil
        guard let session = pendingSession else {
            onComplete?(nil)
            return
        }
        presentNextCelebrationOrTimeReclaimed(for: session)
    }

    /// Called when the weekly-goal milestone celebration is dismissed
    func dismissGoalCelebration() {
        celebratedGoalMilestone = nil
        guard let session = pendingSession else {
            onComplete?(nil)
            return
        }
        presentTimeReclaimedMoment(for: session)
    }

    private func presentNextCelebrationOrTimeReclaimed(for session: Session) {
        if let goalMilestone = pendingGoalMilestone {
            pendingGoalMilestone = nil
            audioService.playHaptic(UINotificationFeedbackGenerator.FeedbackType.success)
            celebratedGoalMilestone = goalMilestone
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
            daysLit: storageService.stats.daysLit
        )
    }

    /// Called when the Time Reclaimed reveal is dismissed — the last step
    /// before the session screen closes.
    func dismissTimeReclaimed() {
        timeReclaimedMoment = nil
        onComplete?(pendingSession)
    }

}
