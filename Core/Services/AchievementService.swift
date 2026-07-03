import Foundation
import Combine

/// Single ledger for unlocked achievements (page milestones today; XP, quests,
/// and other unlockables later — see GAMIFICATION.md).
final class AchievementService: ObservableObject {

    // MARK: - Singleton
    static let shared = AchievementService()

    // MARK: - Published Properties
    @Published private(set) var unlockedThresholds: Set<Int> = []

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let achievementsKey = "verg.achievements"

    // MARK: - Initialization
    private init(storageService: StorageService = .shared) {
        if let data = userDefaults.data(forKey: achievementsKey),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            unlockedThresholds = Set(decoded)
        } else {
            // First run after update: backfill milestones the user already
            // passed so they aren't celebrated retroactively.
            unlockedThresholds = Milestone.earnedThresholds(
                totalSessions: storageService.stats.totalSessions
            )
            save()
        }
    }

    // MARK: - Milestone Checks
    /// Records all newly crossed milestones and returns the highest one to
    /// celebrate, or nil if nothing new was crossed.
    @discardableResult
    func checkForNewMilestones(totalSessions: Int) -> Milestone? {
        let newly = Milestone.newlyCrossed(totalSessions: totalSessions, unlocked: unlockedThresholds)
        guard !newly.isEmpty else { return nil }
        unlockedThresholds.formUnion(newly.map(\.threshold))
        save()
        return newly.max(by: { $0.threshold < $1.threshold })
    }

    func isUnlocked(_ milestone: Milestone) -> Bool {
        unlockedThresholds.contains(milestone.threshold)
    }

    // MARK: - Persistence
    private func save() {
        guard let encoded = try? JSONEncoder().encode(Array(unlockedThresholds).sorted()) else { return }
        userDefaults.set(encoded, forKey: achievementsKey)
    }
}
