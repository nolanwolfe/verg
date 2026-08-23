import Foundation

/// A finished journal — an archived collection of pages (sessions).
/// Non-destructive: books only reference session IDs; the flat sessions
/// array in StorageService remains the source of truth.
struct Book: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    /// Accent color for the cover — index into BookCoverView.palette.
    /// 0 (the first entry) is the original warm leather look.
    var colorIndex: Int
    /// A short, user-written line about this book — a memory, not a
    /// description. Shown beside the date range; empty by default.
    var note: String
    let startDate: Date
    let endDate: Date
    let sessionIDs: [UUID]
    let coverStyle: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        colorIndex: Int = 0,
        note: String = "",
        startDate: Date,
        endDate: Date,
        sessionIDs: [UUID],
        coverStyle: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.colorIndex = colorIndex
        self.note = note
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

// MARK: - Codable (tolerant decoding)
extension Book {
    enum CodingKeys: String, CodingKey {
        case id, title, colorIndex, note, startDate, endDate, sessionIDs, coverStyle, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        // colorIndex didn't exist before customization — default to the
        // classic leather cover so existing books keep their look.
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        // note didn't exist before — default to empty for existing books.
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        sessionIDs = try container.decode([UUID].self, forKey: .sessionIDs)
        coverStyle = try container.decode(Int.self, forKey: .coverStyle)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
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

    /// Resolve this book's pages from the flat session list (tolerates
    /// sessions deleted after the book was made)
    func resolveSessions(from sessions: [Session]) -> [Session] {
        let byID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        return sessionIDs.compactMap { byID[$0] }
    }
}
