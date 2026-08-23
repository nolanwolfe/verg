import Foundation

/// A folder of the user's own prompts. Built-in prompts don't belong to a
/// folder — they're a fixed set that always exists.
struct PromptFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

/// One prompt. Built-ins are constructed from `WritingPrompt.builtIn` and
/// never persisted; the user's own are stored with the folder they sit in.
struct WritingPrompt: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    /// nil = loose, sitting outside any folder.
    var folderID: UUID?
    let createdAt: Date

    init(id: UUID = UUID(), text: String, folderID: UUID? = nil, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.folderID = folderID
        self.createdAt = createdAt
    }
}

// MARK: - Built-in prompts
extension WritingPrompt {
    /// Short by design — a prompt is a door, not a paragraph. Per VOICE.md:
    /// no questions the app answers for you, no therapy framing, no praise.
    /// These are openings, and the paper does the rest.
    static let builtInTexts: [String] = [
        "Name the thing you keep almost doing.",
        "What would change if you stopped waiting to be ready.",
        "Describe today in the words you'd use to a stranger.",
        "What you are protecting by staying busy.",
        "The last time you felt genuinely unhurried.",
        "Something you believe that you have never said out loud.",
        "Who you are when nobody needs anything from you.",
        "What you would keep if you could keep one thing.",
        "The advice you give that you do not take.",
        "What you are further along in than you admit.",
        "Describe a room you could draw from memory.",
        "The story you tell about yourself, and where it bends.",
        "What you would attempt at half the current stakes.",
        "Something you outgrew without noticing.",
        "The hour of today you would live again.",
        "What you are owed, and whether you want it.",
        "A kindness you were shown and never repaid.",
        "What you are pretending not to have decided.",
        "The version of this year you still have time for.",
        "Where your attention actually went today.",
        "What silence usually interrupts.",
        "Something true that took you years to learn.",
        "The question you have stopped asking yourself.",
        "What you would write if this page were burned after."
    ]

    static let builtIn: [WritingPrompt] = builtInTexts.map { WritingPrompt(text: $0) }
}

// MARK: - Selection
extension WritingPrompt {
    /// Next prompt in the shuffle, never repeating `current` unless the pool
    /// holds only one. Pure so it can be tested without a view.
    static func next(from pool: [WritingPrompt], after current: WritingPrompt?) -> WritingPrompt? {
        guard !pool.isEmpty else { return nil }
        guard pool.count > 1, let current else { return pool.randomElement() }
        return pool.filter { $0.id != current.id }.randomElement()
    }
}
