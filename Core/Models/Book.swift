import Foundation

/// A finished journal — an archived collection of pages (sessions).
/// Non-destructive: books only reference session IDs; the flat sessions
/// array in StorageService remains the source of truth.
struct Book: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let startDate: Date
    let endDate: Date
    let sessionIDs: [UUID]
    let coverStyle: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        sessionIDs: [UUID],
        coverStyle: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.sessionIDs = sessionIDs
        self.coverStyle = coverStyle
        self.createdAt = createdAt
    }

    var pageCount: Int { sessionIDs.count }

    /// e.g. "May – Jul 2026"
    var formattedDateRange: String {
        let formatter = DateIntervalFormatter()
        formatter.dateTemplate = "MMM y"
        return formatter.string(from: startDate, to: endDate)
    }
}

// MARK: - Pure grouping logic (testable standalone)
extension Book {
    /// Sessions not archived into any book — the "current journal"
    static func currentSessions(from sessions: [Session], books: [Book]) -> [Session] {
        let booked = Set(books.flatMap(\.sessionIDs))
        return sessions.filter { !booked.contains($0.id) }
    }

    /// Build a book archiving the given sessions; nil if there is nothing to archive
    static func make(title: String, archiving sessions: [Session], coverStyle: Int) -> Book? {
        guard !sessions.isEmpty else { return nil }
        let dates = sessions.map(\.date)
        return Book(
            title: title,
            startDate: dates.min() ?? Date(),
            endDate: dates.max() ?? Date(),
            sessionIDs: sessions.map(\.id),
            coverStyle: coverStyle
        )
    }

    /// Resolve this book's sessions against the source-of-truth array,
    /// tolerating IDs whose sessions have since been deleted.
    func resolveSessions(from all: [Session]) -> [Session] {
        let ids = Set(sessionIDs)
        return all.filter { ids.contains($0.id) }
    }
}
