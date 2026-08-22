import Foundation

/// Service for managing session gating logic
/// Determines whether a user can start a new session based on their subscription status
/// and completed session count
@MainActor
final class SessionGatingService {

    // MARK: - Singleton
    static let shared = SessionGatingService()

    // MARK: - Dependencies
    private let storageService: StorageService
    private let purchaseService: PurchaseService

    // MARK: - Constants
    /// Writing — lighting the candle, the timer, the bell — is always free
    /// and unlimited. Free users get one saved page; the paywall gates
    /// every save after that, not starting a session.
    nonisolated static let freePhotoLimit = 1

    // MARK: - Initialization
    init(
        storageService: StorageService = .shared,
        purchaseService: PurchaseService = .shared
    ) {
        self.storageService = storageService
        self.purchaseService = purchaseService
    }

    // MARK: - Public API

    /// Number of pages (photos) saved so far
    var completedSessionCount: Int {
        storageService.sessions.count
    }

    /// Whether the user is a premium subscriber or has friends & family access
    var isPremium: Bool {
        purchaseService.isSubscribed || purchaseService.isFriendsAndFamily
    }

    /// Writing itself is always free and unlimited — nothing gates starting
    /// the candle/timer.
    var canStartSession: Bool { true }

    /// Whether the user can save another photographed page for free.
    var canSavePhoto: Bool {
        Self.canSavePhoto(isPremium: isPremium, completedPhotoCount: completedSessionCount)
    }

    /// Whether the paywall should show when the user tries to save a page
    var shouldShowPaywallForPhoto: Bool {
        !canSavePhoto
    }

    /// Remaining free page saves (0 if premium or exceeded limit)
    var remainingFreePhotos: Int {
        if isPremium {
            return Int.max // Unlimited for premium
        }
        return max(0, Self.freePhotoLimit - completedSessionCount)
    }

    // MARK: - Pure Gating Logic (for testing)

    /// Pure function to determine if another page can be saved for free
    /// - Parameters:
    ///   - isPremium: Whether the user has premium subscription
    ///   - completedPhotoCount: Number of pages already saved
    /// - Returns: true if the save can proceed without the paywall
    nonisolated static func canSavePhoto(isPremium: Bool, completedPhotoCount: Int) -> Bool {
        if isPremium {
            return true
        }
        return completedPhotoCount < freePhotoLimit
    }

    /// Instance method wrapper for testability
    nonisolated func canSavePhoto(isPremium: Bool, completedPhotoCount: Int) -> Bool {
        Self.canSavePhoto(isPremium: isPremium, completedPhotoCount: completedPhotoCount)
    }

    // MARK: - Logging

    /// Logs current gating status (useful for debugging)
    func logGatingStatus() {
        #if DEBUG
        print("[SessionGating] Premium: \(isPremium), Saved Pages: \(completedSessionCount), Can Save Next: \(canSavePhoto)")
        #endif
    }
}

// MARK: - Testable Helper
extension SessionGatingService {

    /// Creates a test instance with mock values
    /// Only for unit testing - not for production use
    #if DEBUG
    static func makeForTesting(
        storageService: StorageService = .shared,
        purchaseService: PurchaseService = .shared
    ) -> SessionGatingService {
        return SessionGatingService(
            storageService: storageService,
            purchaseService: purchaseService
        )
    }
    #endif
}
