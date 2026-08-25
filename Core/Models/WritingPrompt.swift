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
    /// Oracles don't ask — they say the thing that opens the question in
    /// you. Every line here infers its question and never closes with one;
    /// short by design, because a prompt is a door, not a paragraph.
    ///
    /// VOICE.md's rule holds: no question the *app* answers for you, no
    /// therapy framing, no praise.
    ///
    /// Nothing here sets a length. An earlier set said "in one sentence" and
    /// "in three sentences", which is the opposite of the point — the whole
    /// app is a candle burning down while you keep writing, and a prompt has
    /// no business telling you when to stop.
    static let builtInTexts: [String] = [
        "What you keep almost doing.",
        "What would change if you stopped waiting.",
        "Today, described to a stranger.",
        "What staying busy protects.",
        "The last time you were unhurried.",
        "What you believe and have never said aloud.",
        "Who you are when nobody needs anything.",
        "The one thing you would keep.",
        "Advice you give and do not take.",
        "How far along you really are.",
        "A room you could draw from memory.",
        "Where the story you tell about yourself bends.",
        "What you would attempt at half the stakes.",
        "What you outgrew without noticing.",
        "The hour of today worth living twice.",
        "What you are owed, and whether you want it.",
        "Kindness shown to you and never repaid.",
        "What you pretend not to have decided.",
        "How much of this year is still yours.",
        "Where your attention actually went today.",
        "What silence usually interrupts.",
        "What took years to learn.",
        "The question you stopped asking yourself.",
        "What you would write if this page burned after.",

        // The day — concrete, low barrier, works on an ordinary evening.
        "What today cost, and what it bought.",
        "The first thing you noticed this morning.",
        "What went right that nobody saw.",
        "Who you spoke to today, and what went unsaid.",
        "The part of today you would edit out.",
        "What you did today that no one saw.",
        "Where the hour went.",
        "What you carried around all day.",
        "The last thing that stopped you mid-walk.",
        "What you ate, where you sat, who was there.",

        // Stuck — for the nights the page stays empty.
        "What you keep deleting.",
        "What you would say if you knew it would be read.",
        "Why you almost did not sit down.",
        "The most boring true thing, written first.",
        "What you avoid by reading this instead.",
        "What the resistance feels like before the argument.",
        "The easiest true thing you can write.",
        "What you would rather be doing, and whether you mean it.",

        // The work.
        "What you are building.",
        "The part of the work you keep postponing.",
        "Who this is for.",
        "What would still be worth doing if it failed.",
        "What you are quietly good at.",
        "What you rehearse instead of doing.",
        "The next smallest step, named exactly.",
        "What you would stop if no one noticed.",

        // People.
        "Who you think about who does not know it.",
        "When you last changed your mind about someone.",
        "What you never thanked them for.",
        "The conversation you are still finishing in your head.",
        "Who you are easiest around.",
        "What you would say if it were the last chance.",
        "Who you have outgrown, and whether it is true.",
        "What you inherited that you did not choose.",

        // Memory and time.
        "One image that holds a whole year.",
        "What you kept for no practical reason.",
        "The house you still dream about.",
        "What you can still smell.",
        "Who you were ten years ago.",
        "The last thing you memorised on purpose.",
        "The day something changed quietly.",
        "The warning you were given that turned out true.",

        // Closer to the bone.
        "What you have not admitted wanting.",
        "Where you are wrong.",
        "What you do when you think it does not count.",
        "Where you are performing.",
        "What you would confess to a stranger on a train.",
        "The gap between how you sound and how you are.",
        "What you are afraid is true.",
        "What you forgive yourself for, and what you do not.",

        // Endings.
        "What this season has been about.",
        "What you are ready to put down.",
        "What you will not carry into next year.",
        "A name for the last three months.",
        "What ended without a ceremony.",
        "What you want the next page to say."
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
