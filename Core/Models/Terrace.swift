import Foundation

/// Days-lit milestones. Deliberately quiet: no badges, no points, no tier
/// names the user has to learn — just the plain number, stated once, on
/// the calendar and after the bell.
struct Terrace: Identifiable, Codable, Equatable {
    let daysLitThreshold: Int
    let title: String

    var id: Int { daysLitThreshold }
}

extension Terrace {
    static let all: [Terrace] = [
        Terrace(daysLitThreshold: 7, title: "Seven days lit."),
        Terrace(daysLitThreshold: 14, title: "Fourteen days lit."),
        Terrace(daysLitThreshold: 30, title: "Thirty days lit."),
        Terrace(daysLitThreshold: 50, title: "Fifty days lit."),
        Terrace(daysLitThreshold: 75, title: "Seventy-five days lit."),
        Terrace(daysLitThreshold: 100, title: "One hundred days lit."),
        Terrace(daysLitThreshold: 150, title: "One hundred and fifty days lit.")
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
