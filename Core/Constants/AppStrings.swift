import Foundation

/// Centralized strings/copy for the Verg app
/// All user-facing text should be defined here for easy maintenance and localization
enum AppStrings {

    // MARK: - Onboarding
    enum Onboarding {
        // Step 0 — the epigraph (Longfellow's Inferno I)
        static let epigraphQuote = """
        Thou art my master, and my author thou,
        Thou art alone the one from whom I took
        The beautiful style that has done honour to me.
        """
        static let epigraphAttribution = "Dante to Virgil, in the dark wood."

        // Step 1 — what this is
        static let pitchHeadline = "A journal you write by hand."
        static let pitchSubline = "Pen, paper, ten minutes."

        // Step 2 — the ritual
        static let ritualTitle = "The ritual"
        // "until the bell", never "until it burns out" — a candle going out
        // is what a missed day means. Don't overload the metaphor.
        static let ritualSteps: [(icon: String, text: String)] = [
            ("candle", "Light the candle"),
            ("iphone.slash", "Phone face down"),
            ("pencil", "Write until the bell"),
            ("camera.fill", "Capture the page")
        ]

        // Step 3 — commitment
        static let commitmentTitle = "Choose your pace."
        static let commitmentSubtitle = "Pick a number you can keep."
        static let commitmentOptions: [Int] = [3, 5, 7]

        // Step 4 — projection
        static let projectionIntro = "At that pace, in a year:"

        // Step 5 — the closing note. Mentions the rating; deliberately does
        // NOT trigger the system prompt, which fires on the third saved page.
        static let ratingPromptTitle = "One more thing."
        static let ratingPromptBody = "Ratings light the way. They help others find Verg 🕯️"

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

        /// The candle count as a standalone badge, or nil when unlit. One
        /// day is a start, not yet a run. Shared so the Write screen and
        /// the post-session card can never drift apart on it.
        static func daysLitBadge(_ daysLit: Int) -> String? {
            switch daysLit {
            case ..<1: return nil
            case 1: return "1 day lit"
            default: return "\(daysLit) days lit"
            }
        }

        static func sessionsTodayText(_ count: Int) -> String {
            switch count {
            case 0: return startFirstSession
            case 1: return "1 writing session today"
            default: return "\(count) writing sessions today"
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
        /// The three commands come first, all one size, then the title
        /// lands under them as the thing they add up to.
        ///
        /// Left unfinished on purpose: naming the thing (it was "Becoming")
        /// answered the question for the reader. The blank hands it back, and
        /// whatever they fill in is what they'd be paying for.
        static let lead = "Write what you are"
        static let title = "On the Verg 🕯️ of ______"
        /// Kept for the context-aware case, where the paywall opened from a
        /// specific locked page and says so instead.
        static let subtitle = "Put the phone down. Light the candle. Write what you are."
        /// The product's name. Used wherever it is referred to as a thing —
        /// the Settings row, the locked-page button, the sentence "The
        /// Golden Age opens it." Not the button copy: see `ctaAction`.
        static let ctaTitle = "The Golden Age"
        /// The paywall's own button, which asks for an action rather than
        /// naming a product. Split from `ctaTitle` after renaming that one
        /// silently renamed the product on the locked page too.
        static let ctaAction = "Enter The Golden Age"
        static let contextSubtitleFormat = "%@ is still here."
        static let footerAssurance = "Writing is free. It always will be."
        static let restorePurchases = "Restore Purchases"

        struct Review {
            let quote: String
            let attribution: String
        }

        /// The five-star reviews, as a running joke: an ancient oracle and a
        /// dead poet, neither of whom owns a phone, both writing like
        /// present-day teenagers.
        ///
        /// Deliberately unlabelled: the owner's call is that these read as
        /// the joke they are, given an app named for Virgil that opens on a
        /// Dante epigraph. An explicit "Not real reviews." line was tried
        /// here and cut as redundant.
        ///
        /// Recorded because it's a judgement call with a downside, and the
        /// downside grew when the first attribution changed from "Sibylla"
        /// to "Shiloh" at the owner's request. "Sibylla" and "Dante" were an
        /// oracle and a dead poet — nobody mistakes either for a customer.
        /// "Shiloh" is an ordinary given name, so the first card now reads
        /// as a real person's testimonial beside a Buy button, which is
        /// squarely what Guideline 2.3.1 and the FTC's 2024 consumer-review
        /// rule are aimed at.
        ///
        /// Two one-line fixes if App Review ever reads it as genuine: put an
        /// epithet back ("Dante, c. 1320") and return the first card to a
        /// mythological name, or restore a short disclosure under the cards.
        /// The clean resolution is for the quote to be real — copied
        /// verbatim from App Store Connect — at which point the risk is gone
        /// rather than mitigated.
        ///
        /// They also stay clear of health claims. Nothing here promises a
        /// therapeutic outcome, which a paywall has no business doing.
        ///
        /// Add an actual user review only if it's real, copied verbatim from
        /// App Store Connect. A straight-faced invented one would be a fake
        /// review under App Store Review Guideline 2.3.1 and the FTC's 2024
        /// consumer-review rule.
        ///
        /// Order matters: the first entry is the one small screens show on
        /// its own (see `NativePaywallView`).
        static let reviews: [Review] = [
            Review(
                quote: "ok so i've filled FOUR notebooks and my handwriting is unreal now?? obsessed.",
                attribution: "Shiloh"
            ),
            Review(
                quote: "not to be dramatic but journaling is my whole personality now. worth it.",
                attribution: "Dante"
            )
        ]

        static let laurelBadge = "Anti-phone App"

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
