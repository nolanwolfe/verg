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
        "What you would write if this page were burned after.",

        // The day — concrete, low barrier, works on an ordinary evening.
        "What today cost you, and what it bought.",
        "The first thing you noticed this morning.",
        "Something small that went right.",
        "Who you spoke to today, and what went unsaid.",
        "The part of today you would edit out.",
        "What you did today that no one saw.",
        "Where you lost an hour.",
        "Something you carried around all day.",
        "The last thing that made you stop walking.",
        "What you ate, where you sat, who was there.",

        // Stuck — for the nights the page stays empty.
        "Write the sentence you keep deleting.",
        "What you would say if you knew it would be read.",
        "The reason you almost didn't sit down.",
        "Start with the most boring true thing.",
        "What you are avoiding by reading this.",
        "Describe the resistance without arguing with it.",
        "The easiest true sentence you can write.",
        "What you would rather be doing, and whether you mean it.",

        // The work.
        "What you are building, in one sentence.",
        "The part of the work you keep postponing.",
        "Who you are doing this for.",
        "What would still be worth doing if it failed.",
        "The skill you are quietly good at.",
        "What you have been rehearsing instead of doing.",
        "The next smallest step, named exactly.",
        "What you would stop if no one noticed.",

        // People.
        "Someone you think about who does not know it.",
        "The last time you changed your mind about a person.",
        "What you have never thanked them for.",
        "A conversation you are still finishing in your head.",
        "Who you are easiest around.",
        "The thing you would say if it were the last chance.",
        "Someone you have outgrown, and whether that is true.",
        "What you inherited that you did not choose.",

        // Memory and time.
        "A year you could describe in one image.",
        "What you have kept for no practical reason.",
        "The house you dream about.",
        "Something you can still smell.",
        "Who you were ten years ago, in three sentences.",
        "The last thing you memorised on purpose.",
        "A day that changed something quietly.",
        "A warning you were given that turned out to be right.",

        // Closer to the bone.
        "What you want that you have not admitted wanting.",
        "The thing you are wrong about.",
        "What you do when you think it does not count.",
        "Where you are performing.",
        "What you would confess to a stranger on a train.",
        "The gap between how you sound and how you are.",
        "What you are afraid is true.",
        "Something you forgive yourself for, or do not.",

        // Endings.
        "What this season has been about.",
        "Something you are ready to put down.",
        "What you will not carry into next year.",
        "The chapter title for the last three months.",
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
