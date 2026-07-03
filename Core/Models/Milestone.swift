import Foundation

/// A page-count milestone — the first kind of Verg achievement.
/// Pure Foundation so the unlock logic is testable standalone.
struct Milestone: Identifiable, Codable, Equatable {
    let threshold: Int
    let title: String
    let icon: String

    var id: Int { threshold }
}

extension Milestone {
    /// All page milestones, ascending
    static let all: [Milestone] = [
        Milestone(threshold: 10, title: "10 Pages", icon: "book.closed.fill"),
        Milestone(threshold: 25, title: "25 Pages", icon: "books.vertical.fill"),
        Milestone(threshold: 50, title: "50 Pages", icon: "flame.fill"),
        Milestone(threshold: 100, title: "100 Pages", icon: "star.fill"),
        Milestone(threshold: 250, title: "250 Pages", icon: "crown.fill"),
        Milestone(threshold: 500, title: "500 Pages", icon: "laurel.leading"),
        Milestone(threshold: 1000, title: "1,000 Pages", icon: "trophy.fill")
    ]

    /// The next milestone still ahead of the given page count
    static func nextMilestone(after totalSessions: Int) -> Milestone? {
        all.first { $0.threshold > totalSessions }
    }

    /// Progress (0...1) from the last reached milestone toward the next one
    static func progress(totalSessions: Int) -> Double {
        guard let next = nextMilestone(after: totalSessions) else { return 1.0 }
        let previous = all.last(where: { $0.threshold <= totalSessions })?.threshold ?? 0
        let span = Double(next.threshold - previous)
        guard span > 0 else { return 0 }
        return Double(totalSessions - previous) / span
    }

    /// Thresholds already earned at the given page count (used to backfill
    /// existing users without celebrating milestones they passed long ago)
    static func earnedThresholds(totalSessions: Int) -> Set<Int> {
        Set(all.map(\.threshold).filter { $0 <= totalSessions })
    }

    /// Milestones newly crossed given the current count and what's already unlocked
    static func newlyCrossed(totalSessions: Int, unlocked: Set<Int>) -> [Milestone] {
        all.filter { $0.threshold <= totalSessions && !unlocked.contains($0.threshold) }
    }
}
