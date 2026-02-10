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
    nonisolated static let freeSessionsLimit = 3

    // MARK: - Initialization
    init(
        storageService: StorageService = .shared,
        purchaseService: PurchaseService = .shared
    ) {
        self.storageService = storageService
        self.purchaseService = purchaseService
    }

    // MARK: - Public API

    /// Number of completed sessions
    var completedSessionCount: Int {
        storageService.sessions.count
    }

    /// Whether the user is a premium subscriber
    var isPremium: Bool {
        purchaseService.isSubscribed
    }

    /// Whether the user can start a new session
    /// - Returns: true if user is premium OR has not exceeded free session limit
    var canStartSession: Bool {
        return canStartSession(
            isPremium: isPremium,
            completedSessionCount: completedSessionCount
        )
    }

    /// Whether the user should see the paywall when trying to start a session
    var shouldShowPaywall: Bool {
        !canStartSession
    }

    /// Remaining free sessions (0 if premium or exceeded limit)
    var remainingFreeSessions: Int {
        if isPremium {
            return Int.max // Unlimited for premium
        }
        return max(0, Self.freeSessionsLimit - completedSessionCount)
    }

    // MARK: - Pure Gating Logic (for testing)

    /// Pure function to determine if a session can be started
    /// - Parameters:
    ///   - isPremium: Whether the user has premium subscription
    ///   - completedSessionCount: Number of completed sessions
    /// - Returns: true if session can be started
    nonisolated static func canStartSession(isPremium: Bool, completedSessionCount: Int) -> Bool {
        if isPremium {
            return true
        }
        return completedSessionCount < freeSessionsLimit
    }

    /// Instance method wrapper for testability
    nonisolated func canStartSession(isPremium: Bool, completedSessionCount: Int) -> Bool {
        Self.canStartSession(isPremium: isPremium, completedSessionCount: completedSessionCount)
    }

    // MARK: - Logging

    /// Logs current gating status (useful for debugging)
    func logGatingStatus() {
        print("[SessionGating] Premium: \(isPremium), Completed Sessions: \(completedSessionCount), Can Start: \(canStartSession)")
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
