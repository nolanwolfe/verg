import Foundation

/// Represents a single journaling session
struct Session: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    /// Candle length as configured (including any +5-min extensions) —
    /// what the user intended to write for.
    let duration: TimeInterval
    /// Actual foreground time spent writing — excludes any time the app
    /// was backgrounded mid-session. This is what "Time Reclaimed" reports,
    /// not `duration`. See [[verg-app-project]] for why the two diverge.
    let activeDuration: TimeInterval
    let imagePath: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval,
        activeDuration: TimeInterval? = nil,
        imagePath: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.activeDuration = activeDuration ?? duration
        self.imagePath = imagePath
        self.createdAt = createdAt
    }

    // MARK: - Codable (tolerant decoding)
    // activeDuration didn't exist before 2.2 — sessions saved by older
    // versions fall back to `duration` (they predate background-time
    // exclusion, so the full candle length is the best available estimate).
    enum CodingKeys: String, CodingKey {
        case id, date, duration, activeDuration, imagePath, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        imagePath = try container.decode(String.self, forKey: .imagePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        activeDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .activeDuration) ?? duration
    }

    /// Formatted duration string (e.g., "10 min")
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }

    /// Formatted date string (e.g., "Jan 15, 2024")
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Formatted time string (e.g., "8:30 PM")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
