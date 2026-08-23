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
        static let commitmentTitle = "Choose your pace."
        static let commitmentSubtitle = "Pick a number you can keep."
        static let commitmentOptions: [Int] = [3, 5, 7]

        // Step 4 — projection
        static let projectionIntro = "At that pace, in a year:"

        // Step 5 — rating prompt
        static let ratingPromptTitle = "One more thing"
        static let ratingPromptBody = "A rating helps others find Verg."

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
            static let body = "Take a photo of what you wrote to keep your candle lit and archive."
            static let primaryButton = "Upload photo"
            static let tertiaryButton = "+5 more minutes"
            static let secondaryButton = "Skip"
        }
    }

    // MARK: - Home
    enum Home {
        static let beginWriting = "Begin Writing"

        /// Shown when the candle isn't lit today. Distinguishes a
        /// returning user whose candle lapsed from someone who has never
        /// lit one — same zero, different history.
        static let lightCandle = "Light your candle."
        static let candleWentOut = "The candle went out. Light it again."
        static let startFirstSession = "Start your first session."

        static func daysLitText(daysLit: Int, longestDaysLit: Int) -> String {
            switch daysLit {
            case 0: return longestDaysLit > 0 ? candleWentOut : lightCandle
            case 1: return "1 day lit"
            default: return "\(daysLit) days lit"
            }
        }

        static func sessionsTodayText(_ count: Int) -> String {
            switch count {
            case 0: return startFirstSession
            case 1: return "1 session today"
            default: return "\(count) sessions today"
            }
        }
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
        static let cameraAccessRequired = "Camera access is required to capture a page."
        static let enableInSettings = "Camera access is required. Enable it in Settings."
        static let unableToAccess = "Unable to access camera"
        static let failedToSave = "Failed to save photo. Try again."
    }

    // MARK: - Paywall
    enum Paywall {
        static let title = "On the Verg of Becoming"
        static let subtitle = "Everything you write, kept."
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
        static let reminderBody = "Take 10 minutes to write."
    }

    // MARK: - Session Gating
    enum SessionGating {
        /// Writing is unlimited; free users get one saved page before the
        /// paywall gates further saves.
        static let freePhotoLimit = 1
    }
}
