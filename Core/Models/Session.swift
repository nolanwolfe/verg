import Foundation

/// Represents a single journaling session
struct Session: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let imagePath: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval,
        imagePath: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.imagePath = imagePath
        self.createdAt = createdAt
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
