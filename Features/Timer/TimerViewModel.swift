import Foundation
import Combine
import UIKit

/// ViewModel for the Timer screen
final class TimerViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var timeRemaining: TimeInterval = 0
    @Published private(set) var totalDuration: TimeInterval = 0
    @Published private(set) var progress: Double = 1.0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isComplete: Bool = false
    @Published var showCamera: Bool = false
    @Published var showUploadPhotoNotice: Bool = false

    // MARK: - Dependencies
    private let timerService: TimerService
    private let audioService: AudioService
    private let storageService: StorageService
    private let purchaseService: PurchaseService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks
    var onComplete: (() -> Void)?

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
        totalDuration = duration
        timeRemaining = duration

        // Play start bell if sound enabled
        if storageService.settings.soundEnabled {
            audioService.playStartBell()
        }

        // Start timer
        timerService.start(duration: duration)
    }

    func stopTimer() {
        timerService.stopTimer()
    }

    func cancelSession() {
        timerService.stopTimer()
        onComplete?()
    }

    // MARK: - Private Methods
    private func handleTimerComplete() {
        // Play end bell if sound enabled
        if storageService.settings.soundEnabled {
            audioService.playEndBell()
        }

        // Play haptic
        audioService.playHaptic(UINotificationFeedbackGenerator.FeedbackType.success)

        // Always show "Save your page" notice after session completes
        // This prompts user to upload a photo of their writing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showUploadPhotoNotice = true
        }
    }

    // MARK: - Upload Photo Notice Handlers

    /// Called when user taps "Upload photo" on the coach mark notice
    func onUploadPhotoTapped() {
        showUploadPhotoNotice = false
        showCamera = true
    }

    /// Called when user taps "Skip" on the coach mark notice
    func onSkipPhotoTapped() {
        showUploadPhotoNotice = false
        // Session completes without saving a photo
        onComplete?()
    }

    func onPhotoSaved() {
        showCamera = false

        // Session saved - log for debugging
        let sessionCount = storageService.sessions.count
        print("[SessionGating] Photo saved. Total sessions: \(sessionCount)")

        // Complete the session - paywall will show when user tries to START their 4th session
        onComplete?()
    }

}
