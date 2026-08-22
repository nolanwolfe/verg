import Foundation
import Combine

/// Single ledger for unlocked achievements (page milestones today; XP, quests,
/// and other unlockables later — see GAMIFICATION.md).
final class AchievementService: ObservableObject {

    // MARK: - Singleton
    static let shared = AchievementService()

    // MARK: - Published Properties
    @Published private(set) var unlockedThresholds: Set<Int> = []
    @Published private(set) var unlockedGoalWeekThresholds: Set<Int> = []
    @Published private(set) var unlockedTerraceThresholds: Set<Int> = []

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let achievementsKey = "verg.achievements"
    private let goalAchievementsKey = "verg.goalAchievements"
    private let terraceAchievementsKey = "verg.terraceAchievements"

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

        if let data = userDefaults.data(forKey: goalAchievementsKey),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            unlockedGoalWeekThresholds = Set(decoded)
        } else if let goalDaysPerWeek = storageService.settings.weeklyCommitmentDaysPerWeek {
            let weeksMet = WeeklyGoalTracker.weeksGoalMet(
                sessions: storageService.sessions,
                goalDaysPerWeek: goalDaysPerWeek
            )
            unlockedGoalWeekThresholds = WeeklyGoalMilestone.earnedThresholds(weeksMet: weeksMet)
            saveGoalAchievements()
        }

        if let data = userDefaults.data(forKey: terraceAchievementsKey),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            unlockedTerraceThresholds = Set(decoded)
        } else {
            unlockedTerraceThresholds = Terrace.earnedThresholds(daysLit: storageService.stats.daysLit)
            saveTerraceAchievements()
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

    // MARK: - Weekly Goal Milestone Checks
    /// Records all newly crossed weekly-goal milestones and returns the
    /// highest one to celebrate, or nil if nothing new was crossed.
    @discardableResult
    func checkForNewWeeklyGoalMilestones(sessions: [Session], goalDaysPerWeek: Int) -> WeeklyGoalMilestone? {
        let weeksMet = WeeklyGoalTracker.weeksGoalMet(sessions: sessions, goalDaysPerWeek: goalDaysPerWeek)
        let newly = WeeklyGoalMilestone.newlyCrossed(weeksMet: weeksMet, unlocked: unlockedGoalWeekThresholds)
        guard !newly.isEmpty else { return nil }
        unlockedGoalWeekThresholds.formUnion(newly.map(\.weeksThreshold))
        saveGoalAchievements()
        return newly.max(by: { $0.weeksThreshold < $1.weeksThreshold })
    }

    func isUnlocked(_ milestone: WeeklyGoalMilestone) -> Bool {
        unlockedGoalWeekThresholds.contains(milestone.weeksThreshold)
    }

    // MARK: - Terrace Checks (days lit — quiet, no full-screen celebration)
    /// Records all newly crossed terraces and returns the highest one, or
    /// nil if nothing new was crossed.
    @discardableResult
    func checkForNewTerraces(daysLit: Int) -> Terrace? {
        let newly = Terrace.newlyCrossed(daysLit: daysLit, unlocked: unlockedTerraceThresholds)
        guard !newly.isEmpty else { return nil }
        unlockedTerraceThresholds.formUnion(newly.map(\.daysLitThreshold))
        saveTerraceAchievements()
        return newly.max(by: { $0.daysLitThreshold < $1.daysLitThreshold })
    }

    func isUnlocked(_ terrace: Terrace) -> Bool {
        unlockedTerraceThresholds.contains(terrace.daysLitThreshold)
    }

    // MARK: - Persistence
    private func save() {
        guard let encoded = try? JSONEncoder().encode(Array(unlockedThresholds).sorted()) else { return }
        userDefaults.set(encoded, forKey: achievementsKey)
    }

    private func saveGoalAchievements() {
        guard let encoded = try? JSONEncoder().encode(Array(unlockedGoalWeekThresholds).sorted()) else { return }
        userDefaults.set(encoded, forKey: goalAchievementsKey)
    }

    private func saveTerraceAchievements() {
        guard let encoded = try? JSONEncoder().encode(Array(unlockedTerraceThresholds).sorted()) else { return }
        userDefaults.set(encoded, forKey: terraceAchievementsKey)
    }
}
