import Foundation

/// Centralized strings/copy for the Verg app
/// All user-facing text should be defined here for easy maintenance and localization
enum AppStrings {

    // MARK: - Onboarding
    enum Onboarding {
        // Step 1 — what this is
        static let whatThisIsLine = "Light a candle. Write until it burns out."

        // Step 2 — the ritual
        static let ritualTitle = "The ritual"
        static let ritualSteps: [(icon: String, text: String)] = [
            ("flame.fill", "Light the candle"),
            ("iphone.slash", "Put your phone face down"),
            ("pencil", "Write on paper until the bell"),
            ("camera.fill", "Photograph the page")
        ]

        // Step 3 — commitment
        static let commitmentTitle = "How many days a week?"
        static let commitmentSubtitle = "Pick a pace you can actually keep."
        static let commitmentOptions: [Int] = [3, 5, 7]

        // Step 4 — projection
        static let projectionIntro = "At that pace, in a year:"

        // Step 5 — rating prompt
        static let ratingPromptTitle = "One more thing"
        static let ratingPromptBody = "If Verg's for you, a rating helps other people find it."

        static let skipButton = "Skip"
        static let continueButton = "Continue"
    }

    // MARK: - Coach Mark Notices
    enum CoachMark {
        enum StartTimer {
            static let title = "Start the timer"
            static let body = "Set your phone down. Write on paper while the candle burns."
            static let primaryButton = "Start session"
            static let secondaryButton = "Not now"
        }

        enum UploadPhoto {
            static let title = "Save your page"
            static let body = "Take a photo of what you wrote to keep your streak and archive."
            static let primaryButton = "Upload photo"
            static let tertiaryButton = "+5 more minutes"
            static let secondaryButton = "Skip"
        }
    }

    // MARK: - Home
    enum Home {
        static let beginWriting = "Begin Writing"
        static let startStreak = "Start your streak today!"
        static let dayStreak = "day streak"
        static let daysStreak = "day streak"
        static let sessionToday = "1 session today"
        static let sessionsToday = "sessions today"
        static let startFirstSession = "Start your first session today!"
    }

    // MARK: - Timer
    enum Timer {
        static let cancel = "Cancel"
        static let writing = "Writing..."
    }

    // MARK: - Camera
    enum Camera {
        static let capture = "Capture"
        static let retake = "Retake"
        static let usePhoto = "Use Photo"
        static let cancel = "Cancel"
        static let cameraAccessRequired = "Camera access is required to capture your journal page."
        static let enableInSettings = "Camera access is required. Please enable it in Settings."
        static let unableToAccess = "Unable to access camera"
        static let failedToSave = "Failed to save photo. Please try again."
    }

    // MARK: - Paywall
    enum Paywall {
        static let title = "Unlock Verg"
        static let restorePurchases = "Restore Purchases"
    }

    // MARK: - Settings
    enum Settings {
        static let title = "Settings"
        static let timerDuration = "Timer Duration"
        static let sound = "Sound"
        static let notifications = "Notifications"
        static let notificationTime = "Notification Time"
        static let restorePurchases = "Restore Purchases"
        static let privacyPolicy = "Privacy Policy"
        static let termsOfService = "Terms of Service"
        static let rateApp = "Rate App"
        static let shareApp = "Share App"

        #if DEBUG
        static let debugSection = "Debug"
        static let resetFreeSessionCount = "Reset Free Session Count"
        static let clearAllData = "Clear All Data"
        #endif
    }

    // MARK: - Notifications
    enum Notifications {
        static let reminderTitle = "Time to Write"
        static let reminderBody = "Take 10 minutes to journal your thoughts."
    }

    // MARK: - Session Gating
    enum SessionGating {
        /// Writing is unlimited; free users get one saved page before the
        /// paywall gates further saves.
        static let freePhotoLimit = 1
    }
}
