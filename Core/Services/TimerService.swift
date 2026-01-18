import Foundation
import Combine
import UIKit

/// Service for managing the countdown timer
final class TimerService: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var timeRemaining: TimeInterval = 0
    @Published private(set) var totalDuration: TimeInterval = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isComplete: Bool = false

    // MARK: - Private Properties
    private var timer: Timer?
    private var startTime: Date?
    private var endTime: Date?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Computed Properties
    /// Progress from 1.0 (full) to 0.0 (empty)
    var progress: Double {
        guard totalDuration > 0 else { return 1.0 }
        return timeRemaining / totalDuration
    }

    /// Formatted time remaining (MM:SS)
    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted time with leading zero for minutes
    var formattedTimeFull: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Initialization
    init() {
        setupNotifications()
    }

    deinit {
        stopTimer()
        removeNotifications()
    }

    // MARK: - Timer Control
    /// Start the timer with a given duration
    func start(duration: TimeInterval) {
        stopTimer()

        totalDuration = duration
        timeRemaining = duration
        isRunning = true
        isComplete = false
        startTime = Date()
        endTime = Date().addingTimeInterval(duration)

        // Keep screen awake
        UIApplication.shared.isIdleTimerDisabled = true

        // Start background task
        beginBackgroundTask()

        // Create timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }

        // Ensure timer fires during scrolling
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// Stop the timer
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false

        // Allow screen to sleep
        UIApplication.shared.isIdleTimerDisabled = false

        // End background task
        endBackgroundTask()
    }

    /// Pause the timer
    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// Resume the timer
    func resume() {
        guard !isComplete && timeRemaining > 0 else { return }

        isRunning = true
        endTime = Date().addingTimeInterval(timeRemaining)

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }

        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// Reset the timer
    func reset() {
        stopTimer()
        timeRemaining = totalDuration
        isComplete = false
    }

    // MARK: - Private Methods
    private func tick() {
        guard let endTime = endTime else { return }

        let remaining = endTime.timeIntervalSinceNow

        if remaining <= 0 {
            timeRemaining = 0
            complete()
        } else {
            timeRemaining = remaining
        }
    }

    private func complete() {
        stopTimer()
        isComplete = true
    }

    // MARK: - Background Task Management
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // MARK: - App Lifecycle Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appDidEnterBackground() {
        // Timer continues with the scheduled end time
    }

    @objc private func appWillEnterForeground() {
        // Recalculate remaining time based on end time
        guard isRunning, let endTime = endTime else { return }

        let remaining = endTime.timeIntervalSinceNow

        if remaining <= 0 {
            timeRemaining = 0
            complete()
        } else {
            timeRemaining = remaining
        }
    }
}
