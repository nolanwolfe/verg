import Foundation

/// The seven terraces of Purgatory — days-lit milestones. Deliberately
/// quiet: no badges, no points, no currency. A marked day and one line of
/// text, surfaced on the calendar and after the bell. The seventh is the
/// summit.
struct Terrace: Identifiable, Codable, Equatable {
    let daysLitThreshold: Int
    let title: String

    var id: Int { daysLitThreshold }
}

extension Terrace {
    static let all: [Terrace] = [
        Terrace(daysLitThreshold: 7, title: "The first terrace."),
        Terrace(daysLitThreshold: 14, title: "The second terrace."),
        Terrace(daysLitThreshold: 30, title: "The third terrace."),
        Terrace(daysLitThreshold: 60, title: "The fourth terrace."),
        Terrace(daysLitThreshold: 100, title: "The fifth terrace."),
        Terrace(daysLitThreshold: 200, title: "The sixth terrace."),
        Terrace(daysLitThreshold: 365, title: "The summit.")
    ]

    static func nextTerrace(after daysLit: Int) -> Terrace? {
        all.first { $0.daysLitThreshold > daysLit }
    }

    static func earnedThresholds(daysLit: Int) -> Set<Int> {
        Set(all.map(\.daysLitThreshold).filter { $0 <= daysLit })
    }

    static func newlyCrossed(daysLit: Int, unlocked: Set<Int>) -> [Terrace] {
        all.filter { $0.daysLitThreshold <= daysLit && !unlocked.contains($0.daysLitThreshold) }
    }
}
