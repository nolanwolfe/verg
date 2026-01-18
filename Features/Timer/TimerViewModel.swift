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

    // MARK: - Dependencies
    private let timerService: TimerService
    private let audioService: AudioService
    private let storageService: StorageService
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
        storageService: StorageService = .shared
    ) {
        self.timerService = timerService
        self.audioService = audioService
        self.storageService = storageService
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
    func startTimer() {
        let duration = storageService.settings.timerDuration
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

        // Show camera after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showCamera = true
        }
    }

    func onPhotoSaved() {
        showCamera = false
        onComplete?()
    }
}
