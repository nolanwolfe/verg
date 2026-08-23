import Foundation

/// Determines what's free vs. what needs The Golden Age. Writing and saving pages
/// are always free and unlimited — the only thing gated is *viewing*
/// pages older than the free archive window. Nothing is ever deleted or
/// hidden from export; this only affects what's viewable in the journal.
@MainActor
final class SessionGatingService {

    // MARK: - Singleton
    static let shared = SessionGatingService()

    // MARK: - Dependencies
    private let storageService: StorageService
    private let purchaseService: PurchaseService

    // MARK: - Constants
    /// Free users can view pages from the last 7 days. Older pages still
    /// exist, still count toward days lit / milestones, and still export
    /// if the user subscribes later — this only gates viewing.
    nonisolated static let freeArchiveWindowDays = 7

    // MARK: - Initialization
    init(
        storageService: StorageService = .shared,
        purchaseService: PurchaseService = .shared
    ) {
        self.storageService = storageService
        self.purchaseService = purchaseService
    }

    // MARK: - Public API

    /// Whether the user is a premium (The Golden Age) subscriber or has friends & family access
    var isPremium: Bool {
        purchaseService.isSubscribed || purchaseService.isFriendsAndFamily
    }

    /// Writing itself is always free and unlimited — nothing gates
    /// starting the candle/timer, and nothing gates saving the page either.
    var canStartSession: Bool { true }

    /// Whether a page dated `date` is viewable without The Golden Age.
    func canViewPage(dated date: Date) -> Bool {
        Self.canViewPage(isPremium: isPremium, date: date)
    }

    /// Pure function — whether a page is inside the free archive window.
    nonisolated static func canViewPage(
        isPremium: Bool,
        date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        if isPremium { return true }
        guard let cutoff = calendar.date(byAdding: .day, value: -freeArchiveWindowDays, to: now) else {
            return true
        }
        return calendar.startOfDay(for: date) >= calendar.startOfDay(for: cutoff)
    }

    // MARK: - Logging

    /// Logs current gating status (useful for debugging)
    func logGatingStatus() {
        #if DEBUG
        print("[SessionGating] Premium: \(isPremium)")
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
