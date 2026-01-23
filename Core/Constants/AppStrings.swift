import Foundation

/// Centralized strings/copy for the Verg app
/// All user-facing text should be defined here for easy maintenance and localization
enum AppStrings {

    // MARK: - Onboarding
    enum Onboarding {
        struct Page {
            let imageName: String
            let title: String
            let subtitle: String
            let buttonText: String
        }

        static let pages: [Page] = [
            Page(
                imageName: "flame",
                title: "One simple ritual",
                subtitle: "Track your pages. Watch your progress and thoughts grow.",
                buttonText: "Leave the phone alone."
            ),
            Page(
                imageName: "pencil.and.scribble",
                title: "This app isn't for typing — it's for writing",
                subtitle: "Do you have a pen and paper?",
                buttonText: "I'm ready to write on paper"
            ),
            Page(
                imageName: "iphone.radiowaves.left.and.right",
                title: "Your phone steals your thoughts",
                subtitle: "Endless attention. Zero reflection.",
                buttonText: "This is the door out."
            )
        ]

        static let skipButton = "Skip"
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
        static let freeSessionsLimit = 3
    }
}
