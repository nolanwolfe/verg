import Foundation
import CoreGraphics

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
    /// The prompt this page was written to, if one was chosen. Stored as
    /// text rather than an id so the page keeps its prompt even if the
    /// prompt itself is later edited or deleted.
    let prompt: String?
    let createdAt: Date

    /// Where the page sits inside the photo, normalised 0...1 against the
    /// stored image.
    ///
    /// Nil means "centre it", which is what every page saved before framing
    /// existed gets, and what a photo the user did not adjust still gets.
    /// Stored rather than baked into the file so the photo stays whole: the
    /// frame remains a decision, and a future format change can re-derive
    /// from the same rect instead of being stuck with a crop taken under the
    /// old one.
    let cropRect: CGRect?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval,
        activeDuration: TimeInterval? = nil,
        imagePath: String,
        prompt: String? = nil,
        createdAt: Date = Date(),
        cropRect: CGRect? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.activeDuration = activeDuration ?? duration
        self.imagePath = imagePath
        self.prompt = prompt
        self.createdAt = createdAt
        self.cropRect = cropRect
    }

    // MARK: - Codable (tolerant decoding)
    // activeDuration didn't exist before 2.2 — sessions saved by older
    // versions fall back to `duration` (they predate background-time
    // exclusion, so the full candle length is the best available estimate).
    enum CodingKeys: String, CodingKey {
        case id, date, duration, activeDuration, imagePath, prompt, createdAt, cropRect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        imagePath = try container.decode(String.self, forKey: .imagePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        activeDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .activeDuration) ?? duration
        // Absent on every page saved before framing shipped — those centre.
        cropRect = try container.decodeIfPresent(CGRect.self, forKey: .cropRect)
        // prompt didn't exist before prompts shipped — older pages simply
        // have none, which renders as no prompt line rather than an error.
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
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

// MARK: - On this day

/// A page from the same calendar day a year or a month ago, for the card at
/// the top of the journal. Rereading your own handwriting is the payoff of
/// keeping a paper journal; the app had every page and never offered one
/// back.
enum OnThisDay {
    struct Match: Equatable {
        let session: Session
        /// "One year ago today", "Two years ago today", "A month ago today".
        let label: String
    }

    /// The oldest anniversary wins: a page from years ago is a better find
    /// than last month's. Years are checked back to the earliest page; the
    /// month is a fallback so a journal younger than a year still gets one.
    /// Several pages on the matching day: the first written that day.
    static func find(in sessions: [Session], today: Date = Date(), calendar: Calendar = .current) -> Match? {
        guard let earliest = sessions.map(\.date).min() else { return nil }
        let maxYears = max(0, calendar.dateComponents([.year], from: earliest, to: today).year ?? 0)

        func firstPage(on day: Date) -> Session? {
            sessions
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .min { $0.date < $1.date }
        }

        if maxYears >= 1 {
            for years in stride(from: maxYears, through: 1, by: -1) {
                guard let day = calendar.date(byAdding: .year, value: -years, to: today),
                      // Feb 29 maps to Feb 28 in other years; only an exact
                      // same-day match counts, so that one is skipped.
                      calendar.component(.day, from: day) == calendar.component(.day, from: today),
                      let page = firstPage(on: day) else { continue }
                return Match(session: page, label: yearsLabel(years))
            }
        }

        if let day = calendar.date(byAdding: .month, value: -1, to: today),
           calendar.component(.day, from: day) == calendar.component(.day, from: today),
           let page = firstPage(on: day) {
            return Match(session: page, label: "A month ago today")
        }
        return nil
    }

    private static func yearsLabel(_ years: Int) -> String {
        let words = [1: "One", 2: "Two", 3: "Three", 4: "Four", 5: "Five"]
        return "\(words[years] ?? "\(years)") \(years == 1 ? "year" : "years") ago today"
    }
}
