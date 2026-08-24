import Foundation
import UIKit
import Combine
import ImageIO
import UniformTypeIdentifiers

/// Service for persisting sessions, stats, and settings
final class StorageService: ObservableObject {

    // MARK: - Singleton
    static let shared = StorageService()

    // MARK: - Published Properties
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var books: [Book] = []
    @Published private(set) var stats: UserStats = UserStats()
    @Published private(set) var customPrompts: [WritingPrompt] = []
    @Published private(set) var promptFolders: [PromptFolder] = []
    @Published var settings: AppSettings = AppSettings()

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSString, UIImage>()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let imageIOQueue = DispatchQueue(label: "verg.imageio", qos: .userInitiated, attributes: .concurrent)
    // Captured at init (main thread) so downsample never touches UIScreen off-main
    private let displayScale: CGFloat = UIScreen.main.scale

    private let sessionsKey = "verg.sessions"
    private let booksKey = "verg.books"
    private let statsKey = "verg.stats"
    private let settingsKey = "verg.settings"
    private let imageMigrationKey = "verg.imageMigration.v1"
    private let customPromptsKey = "verg.customPrompts"
    private let promptFoldersKey = "verg.promptFolders"

    // MARK: - Initialization
    private init() {
        // The fullscreen viewer keeps a ±2 swipe window of full-resolution
        // pages alive. At the 2048px storage cap each decodes to ~12 MB, so
        // the old 64 MB / 8-object ceiling sat exactly on top of that window:
        // every swipe evicted a page that was about to be needed again, and
        // swiping back re-decoded it in front of the user. Enough headroom
        // that the window plus a couple of neighbours stays resident.
        imageCache.countLimit = 12
        imageCache.totalCostLimit = 112 * 1024 * 1024
        thumbnailCache.countLimit = 400
        thumbnailCache.totalCostLimit = 48 * 1024 * 1024
        loadAllData()
        migrateLegacyImagesIfNeeded()
    }

    // MARK: - Directory Management
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var imagesDirectory: URL {
        let directory = documentsDirectory.appendingPathComponent("JournalImages", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    // MARK: - Load Data
    private func loadAllData() {
        loadSessions()
        loadBooks()
        loadStats()
        loadSettings()
        loadPrompts()

        // Migrate old/testing timer defaults (e.g., 5 seconds) to 10 minutes
        if settings.timerDuration == 5 {
            settings.timerDuration = 600
            saveSettings()
        }

        // Candle gap validation (including premium relights) now runs in
        // CandleService.refreshDaysLit(), which needs PurchaseService's
        // entitlement state — not available at this layer.

        #if DEBUG
        applyUITestOverridesIfNeeded()
        #endif
    }

    #if DEBUG
    /// UI tests launch with `-VergUITest` to start from a known state —
    /// past onboarding and the coach mark, so a test reaches the app itself
    /// rather than the first-run sequence. `-VergAppearance light|dark|system`
    /// pins the theme for a screenshot pass.
    ///
    /// DEBUG-only and inert without the flag, so it cannot affect a release
    /// build or a real launch.
    private func applyUITestOverridesIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-VergUITest") else { return }
        settings.hasSeenOnboarding = true
        settings.hasSeenSetTimerNotice = true
        // Clean slate: a previous run's scripts and folders would otherwise
        // still be here, and a test that creates one then looks for it finds
        // two.
        customPrompts = []
        promptFolders = []
        savePrompts()
        if let index = args.firstIndex(of: "-VergAppearance"),
           index + 1 < args.count,
           let mode = AppearanceMode(rawValue: args[index + 1]) {
            settings.appearance = mode
        }
        if args.contains("-VergSeedData") { seedForUITesting() }
    }

    /// Build a journal out of nothing so the screens that only exist once
    /// there are pages — the grid, the fullscreen viewer, a book — can be
    /// reached by a test. Without this those screens can only ever be seen by
    /// a person with a real journal, which is how they went unverified.
    ///
    /// Pages are drawn, not photographed: ruled lines on paper at the page
    /// aspect, each numbered so a test can tell one from another.
    private func seedForUITesting() {
        sessions = []
        books = []
        stats = UserStats()

        let made: [Session] = (0..<9).compactMap { index in
            guard let data = Self.ruledPage(number: index + 1).jpegData(compressionQuality: 0.7) else { return nil }
            let filename = "uitest-\(index).jpg"
            try? data.write(to: imagesDirectory.appendingPathComponent(filename), options: [.atomic])
            let day = Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date()
            return Session(
                date: day,
                duration: 600,
                activeDuration: 540,
                imagePath: filename,
                prompt: index.isMultiple(of: 3) ? "Name the thing you keep almost doing." : nil,
                createdAt: day
            )
        }
        sessions = made.sorted { $0.createdAt > $1.createdAt }
        stats.totalSessions = made.count
        stats.daysLit = 4
        saveSessions()
        saveStats()

        // Archive the older half so there is a book on the shelf too.
        let archived = Array(sessions.suffix(4))
        if let book = Book.make(title: "Shiloh", archiving: archived, coverStyle: 0) {
            books = [book]
            saveBooks()
        }
    }

    /// A page of ruled paper with a number on it.
    private static func ruledPage(number: Int) -> UIImage {
        let size = CGSize(width: 900, height: 900 / PageCapture.aspectRatio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(white: 0.94, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.55, green: 0.60, blue: 0.72, alpha: 1).setStroke()
            let path = UIBezierPath()
            var y: CGFloat = 60
            while y < size.height - 30 {
                path.move(to: CGPoint(x: 50, y: y))
                path.addLine(to: CGPoint(x: size.width - 50, y: y))
                y += 42
            }
            path.lineWidth = 1
            path.stroke()
            ("\(number)" as NSString).draw(
                at: CGPoint(x: 60, y: 12),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 44),
                    .foregroundColor: UIColor(white: 0.35, alpha: 1)
                ]
            )
        }
    }
    #endif

    private func loadSessions() {
        guard let data = userDefaults.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([Session].self, from: data) else {
            sessions = []
            return
        }
        sessions = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Prompts
    private func loadPrompts() {
        if let data = userDefaults.data(forKey: customPromptsKey),
           let decoded = try? JSONDecoder().decode([WritingPrompt].self, from: data) {
            customPrompts = decoded.sorted { $0.createdAt < $1.createdAt }
        } else {
            customPrompts = []
        }

        if let data = userDefaults.data(forKey: promptFoldersKey),
           let decoded = try? JSONDecoder().decode([PromptFolder].self, from: data) {
            promptFolders = decoded.sorted { $0.createdAt < $1.createdAt }
        } else {
            promptFolders = []
        }
    }

    private func savePrompts() {
        if let encoded = try? JSONEncoder().encode(customPrompts) {
            userDefaults.set(encoded, forKey: customPromptsKey)
        }
        if let encoded = try? JSONEncoder().encode(promptFolders) {
            userDefaults.set(encoded, forKey: promptFoldersKey)
        }
    }

    /// Everything the shuffle draws from: the fixed set plus the user's own.
    var allPrompts: [WritingPrompt] {
        WritingPrompt.builtIn + customPrompts
    }

    @discardableResult
    func addCustomPrompt(_ text: String, folderID: UUID? = nil) -> WritingPrompt? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let prompt = WritingPrompt(text: String(trimmed.prefix(160)), folderID: folderID)
        customPrompts.append(prompt)
        savePrompts()
        return prompt
    }

    func updateCustomPrompt(id: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = customPrompts.firstIndex(where: { $0.id == id }), !trimmed.isEmpty else { return }
        customPrompts[index].text = String(trimmed.prefix(160))
        savePrompts()
    }

    func moveCustomPrompt(id: UUID, toFolder folderID: UUID?) {
        guard let index = customPrompts.firstIndex(where: { $0.id == id }) else { return }
        customPrompts[index].folderID = folderID
        savePrompts()
    }

    func deleteCustomPrompt(id: UUID) {
        customPrompts.removeAll { $0.id == id }
        savePrompts()
    }

    @discardableResult
    func addPromptFolder(_ name: String) -> PromptFolder? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let folder = PromptFolder(name: String(trimmed.prefix(40)))
        promptFolders.append(folder)
        savePrompts()
        return folder
    }

    func renamePromptFolder(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let index = promptFolders.firstIndex(where: { $0.id == id }), !trimmed.isEmpty else { return }
        promptFolders[index].name = String(trimmed.prefix(40))
        savePrompts()
    }

    /// Deleting a folder keeps its prompts — they fall back to loose rather
    /// than being destroyed along with it.
    func deletePromptFolder(id: UUID) {
        promptFolders.removeAll { $0.id == id }
        for index in customPrompts.indices where customPrompts[index].folderID == id {
            customPrompts[index].folderID = nil
        }
        savePrompts()
    }

    func prompts(inFolder folderID: UUID?) -> [WritingPrompt] {
        customPrompts.filter { $0.folderID == folderID }
    }

    private func loadBooks() {
        guard let data = userDefaults.data(forKey: booksKey),
              let decoded = try? JSONDecoder().decode([Book].self, from: data) else {
            books = []
            return
        }
        books = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func loadStats() {
        guard let data = userDefaults.data(forKey: statsKey),
              let decoded = try? JSONDecoder().decode(UserStats.self, from: data) else {
            stats = UserStats()
            return
        }
        stats = decoded
    }

    private func loadSettings() {
        guard let data = userDefaults.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            settings = AppSettings()
            return
        }
        settings = decoded
    }

    // MARK: - Save Data
    private func saveSessions() {
        guard let encoded = try? JSONEncoder().encode(sessions) else { return }
        userDefaults.set(encoded, forKey: sessionsKey)
    }

    private func saveBooks() {
        guard let encoded = try? JSONEncoder().encode(books) else { return }
        userDefaults.set(encoded, forKey: booksKey)
    }

    private func saveStats() {
        guard let encoded = try? JSONEncoder().encode(stats) else { return }
        userDefaults.set(encoded, forKey: statsKey)
    }

    func saveSettings() {
        guard let encoded = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(encoded, forKey: settingsKey)
    }

    // MARK: - Session Management
    /// Save a new session with the captured image.
    ///
    /// Two phases on purpose. Encoding a 12 MP capture and writing it to disk
    /// takes long enough to drop frames, so it happens off the main thread —
    /// but `sessions` and `stats` are `@Published`, and mutating those from a
    /// background queue is what the caller used to do. That publishes into
    /// SwiftUI off-main, which is undefined behaviour: the journal could miss
    /// the new page, or tear down mid-update. The write is backgrounded and
    /// the state change is not.
    @MainActor
    @discardableResult
    func saveSession(
        image: UIImage,
        duration: TimeInterval,
        activeDuration: TimeInterval? = nil,
        prompt: String? = nil
    ) async -> Session? {
        let filename = "\(UUID().uuidString).jpg"
        let imageURL = imagesDirectory.appendingPathComponent(filename)

        let wrote = await withCheckedContinuation { continuation in
            imageIOQueue.async {
                // Downsize + normalize orientation, then compress and save
                let normalized = Self.normalizeForStorage(image)
                guard let imageData = normalized.jpegData(compressionQuality: 0.8) else {
                    continuation.resume(returning: false)
                    return
                }
                do {
                    // Encrypted at rest while the device is locked — capture
                    // only happens in the foreground, so .complete is safe
                    try imageData.write(to: imageURL, options: [.atomic, .completeFileProtection])
                    continuation.resume(returning: true)
                } catch {
                    #if DEBUG
                    print("Error saving image: \(error)")
                    #endif
                    continuation.resume(returning: false)
                }
            }
        }

        guard wrote else { return nil }

        let session = Session(
            date: Date(),
            duration: duration,
            activeDuration: activeDuration,
            imagePath: filename,
            prompt: prompt,
            createdAt: Date()
        )

        sessions.insert(session, at: 0)
        saveSessions()

        stats.recordSession()
        saveStats()

        return session
    }

    /// Get all sessions
    func getAllSessions() -> [Session] {
        return sessions
    }

    /// Get sessions for a specific date
    func getSessions(for date: Date) -> [Session] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Get session by ID
    func getSession(id: UUID) -> Session? {
        return sessions.first { $0.id == id }
    }

    /// Delete a session
    func deleteSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }

        let session = sessions[index]
        imageCache.removeObject(forKey: session.imagePath as NSString)
        thumbnailCache.removeObject(forKey: "\(session.imagePath)_thumb_200" as NSString)

        let imageURL = imagesDirectory.appendingPathComponent(session.imagePath)
        try? fileManager.removeItem(at: imageURL)

        sessions.remove(at: index)
        saveSessions()

        // Strip the id from any book referencing it
        var booksChanged = false
        for (bookIndex, book) in books.enumerated() where book.sessionIDs.contains(id) {
            books[bookIndex] = Book(
                id: book.id,
                title: book.title,
                startDate: book.startDate,
                endDate: book.endDate,
                sessionIDs: book.sessionIDs.filter { $0 != id },
                coverStyle: book.coverStyle,
                createdAt: book.createdAt
            )
            booksChanged = true
        }
        if booksChanged {
            saveBooks()
        }
    }

    // MARK: - Book Management
    /// Sessions not yet archived into a book — the current journal
    var currentSessions: [Session] {
        Book.currentSessions(from: sessions, books: books)
    }

    /// Archive the current journal's pages as a book and start fresh
    @discardableResult
    func finishCurrentJournal(title: String) -> Book? {
        guard let book = Book.make(
            title: title,
            archiving: currentSessions,
            coverStyle: books.count % 5
        ) else { return nil }

        books.insert(book, at: 0)
        saveBooks()
        return book
    }

    /// Resolve a book's pages (tolerates deleted sessions)
    func sessions(for book: Book) -> [Session] {
        book.resolveSessions(from: sessions)
    }

    /// Delete a book record — its pages return to the current journal
    func deleteBook(id: UUID) {
        books.removeAll { $0.id == id }
        saveBooks()
    }

    /// Rename a book (titles cap at 40 characters so covers stay legible)
    func renameBook(id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard let index = books.firstIndex(where: { $0.id == id }),
              !trimmed.isEmpty else { return }
        books[index].title = String(trimmed.prefix(40))
        saveBooks()
    }

    /// Set a book's cover color (index into BookCoverView.palette)
    func setBookColor(id: UUID, colorIndex: Int) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].colorIndex = colorIndex
        saveBooks()
    }

    /// Set a book's note — a short memory line, capped so it stays a line, not a page
    func setBookNote(id: UUID, note: String) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].note = String(note.prefix(80))
        saveBooks()
    }

    /// Get image for a session (cached, full resolution)
    func getImage(for session: Session) -> UIImage? {
        let key = session.imagePath as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        let imageURL = imagesDirectory.appendingPathComponent(session.imagePath)
        guard let data = try? Data(contentsOf: imageURL),
              let image = UIImage(data: data) else { return nil }
        imageCache.setObject(image, forKey: key, cost: image.memoryCost)
        return image
    }

    /// Get downsampled thumbnail for grid display (cached)
    func getThumbnail(for session: Session, size: CGFloat = 200) -> UIImage? {
        let key = "\(session.imagePath)_thumb_\(Int(size))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        let imageURL = imagesDirectory.appendingPathComponent(session.imagePath)
        guard let thumbnail = downsample(imageAt: imageURL, to: CGSize(width: size, height: size)) else { return nil }
        thumbnailCache.setObject(thumbnail, forKey: key, cost: thumbnail.memoryCost)
        return thumbnail
    }

    /// Synchronous cache-only thumbnail lookup — never touches disk, safe on
    /// the main thread. Lets grid cells and the fullscreen viewer show an
    /// already-decoded thumbnail instantly instead of flashing a placeholder.
    func cachedThumbnail(for session: Session, size: CGFloat = 200) -> UIImage? {
        thumbnailCache.object(forKey: "\(session.imagePath)_thumb_\(Int(size))" as NSString)
    }

    /// Cap stored photos at maxDimension px on the long edge and bake orientation
    /// into the pixels so every later decode is cheap and upright.
    /// Static: touches no instance state, so the save path can call it from a
    /// background queue without capturing the (non-Sendable) service.
    private static func normalizeForStorage(_ image: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longEdge = max(pixelWidth, pixelHeight)

        if longEdge <= maxDimension && image.imageOrientation == .up && image.scale == 1 {
            return image
        }

        let ratio = min(1, maxDimension / longEdge)
        let targetSize = CGSize(width: pixelWidth * ratio, height: pixelHeight * ratio)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Async full-resolution image load off the main thread
    func loadImageAsync(for session: Session) async -> UIImage? {
        if let cached = imageCache.object(forKey: session.imagePath as NSString) { return cached }
        return await withCheckedContinuation { continuation in
            imageIOQueue.async { [weak self] in
                continuation.resume(returning: self?.getImage(for: session))
            }
        }
    }

    /// Async thumbnail load off the main thread
    func loadThumbnailAsync(for session: Session, size: CGFloat = 200) async -> UIImage? {
        let key = "\(session.imagePath)_thumb_\(Int(size))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        return await withCheckedContinuation { continuation in
            imageIOQueue.async { [weak self] in
                continuation.resume(returning: self?.getThumbnail(for: session, size: size))
            }
        }
    }

    // MARK: - Legacy Image Migration
    /// Pages saved before 2.2 kept the full camera resolution (~12 MP), which
    /// makes every decode expensive and is the main source of journal lag on
    /// long-standing installs. One-time pass: re-encode anything over
    /// 2048 px down to the current storage cap and apply file protection.
    /// The done-flag is only set when every file succeeded, so an interrupted
    /// run resumes on the next launch (already-migrated files are skipped
    /// by the dimension check).
    private func migrateLegacyImagesIfNeeded() {
        guard !userDefaults.bool(forKey: imageMigrationKey) else { return }
        let snapshot = sessions
        guard !snapshot.isEmpty else {
            userDefaults.set(true, forKey: imageMigrationKey)
            return
        }
        let directory = imagesDirectory
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var allSucceeded = true
            for session in snapshot {
                let url = directory.appendingPathComponent(session.imagePath)
                guard self.fileManager.fileExists(atPath: url.path) else { continue }
                if self.shrinkStoredImageIfOversized(at: url) {
                    self.imageCache.removeObject(forKey: session.imagePath as NSString)
                } else {
                    allSucceeded = false
                }
            }
            if allSucceeded {
                DispatchQueue.main.async {
                    self.userDefaults.set(true, forKey: self.imageMigrationKey)
                }
            }
        }
    }

    /// Returns true if the file is now within the size cap (shrunk or already
    /// small). Reads only the header to check dimensions, so untouched files
    /// cost almost nothing.
    private func shrinkStoredImageIfOversized(at url: URL, maxDimension: CGFloat = 2048) -> Bool {
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return false
        }
        guard max(width, height) > maxDimension else { return true }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return false
        }

        let tempURL = url.deletingPathExtension().appendingPathExtension("migrating.jpg")
        guard let destination = CGImageDestinationCreateWithURL(
            tempURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return false }
        CGImageDestinationAddImage(
            destination, cgImage,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            try? fileManager.removeItem(at: tempURL)
            return false
        }
        do {
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: tempURL.path
            )
            _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
            return true
        } catch {
            try? fileManager.removeItem(at: tempURL)
            return false
        }
    }

    private func downsample(imageAt url: URL, to pointSize: CGSize) -> UIImage? {
        let scale = displayScale
        let pixelSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(pixelSize.width, pixelSize.height)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Get image URL for a session
    func getImageURL(for session: Session) -> URL {
        return imagesDirectory.appendingPathComponent(session.imagePath)
    }

    // MARK: - Stats Management
    func getStats() -> UserStats {
        return stats
    }

    func updateStats(_ newStats: UserStats) {
        stats = newStats
        saveStats()
    }

    // MARK: - Settings Management
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveSettings()
    }

    func setTimerDuration(_ duration: TimeInterval) {
        settings.timerDuration = duration
        saveSettings()
    }

    func setSoundEnabled(_ enabled: Bool) {
        settings.soundEnabled = enabled
        saveSettings()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        settings.notificationsEnabled = enabled
        saveSettings()
    }

    func setNotificationTime(_ time: Date) {
        settings.notificationTime = time
        saveSettings()
    }

    func setHasSeenOnboarding(_ seen: Bool) {
        settings.hasSeenOnboarding = seen
        saveSettings()
    }

    /// Replay the onboarding ("Guide" in Settings): clear the flag and let
    /// ContentView's existing first-launch overlay logic take over.
    func replayOnboarding() {
        setHasSeenOnboarding(false)
    }

    func setIsSubscribed(_ subscribed: Bool) {
        settings.isSubscribed = subscribed
        saveSettings()
    }

    func setAmbientSoundEnabled(_ enabled: Bool) {
        settings.ambientSoundEnabled = enabled
        saveSettings()
    }

    func setAmbientSoundID(_ id: String) {
        settings.ambientSoundID = id
        saveSettings()
    }

    func setCalendarStyle(_ style: CalendarStyle) {
        settings.calendarStyle = style
        saveSettings()
    }

    func setAppearance(_ mode: AppearanceMode) {
        settings.appearance = mode
        saveSettings()
    }

    func setHasSeenSessionPaywall(_ seen: Bool) {
        settings.hasSeenSessionPaywall = seen
        saveSettings()
    }

    func setWeeklySummaryNotificationsEnabled(_ enabled: Bool) {
        settings.weeklySummaryNotificationsEnabled = enabled
        saveSettings()
    }

    func setWeeklyCommitmentDaysPerWeek(_ days: Int?) {
        settings.weeklyCommitmentDaysPerWeek = days
        saveSettings()
    }

    // MARK: - Coach Mark Notice Management
    func setHasSeenSetTimerNotice(_ seen: Bool) {
        settings.hasSeenSetTimerNotice = seen
        saveSettings()
    }

    func incrementUploadPhotoNoticeShownCount() {
        settings.uploadPhotoNoticeShownCount += 1
        saveSettings()
    }

    /// Whether to show the "upload photo" coach mark notice (shown for first 3 sessions)
    var shouldShowUploadPhotoNotice: Bool {
        settings.uploadPhotoNoticeShownCount < 3
    }

    #if DEBUG
    /// Reset free session count for testing (DEBUG only)
    func resetForTesting() {
        // Clear all sessions
        sessions = []
        saveSessions()

        // Reset stats
        stats = UserStats()
        saveStats()

        // Reset coach mark flags
        settings.hasSeenSetTimerNotice = false
        settings.uploadPhotoNoticeShownCount = 0
        saveSettings()

        #if DEBUG
        print("[DEBUG] StorageService: Reset all data for testing")
        #endif
    }
    #endif

    // MARK: - Utility
    /// Check if there are any sessions
    var hasSessions: Bool {
        !sessions.isEmpty
    }

    /// Get dates with sessions (for calendar)
    func getDatesWithSessions() -> Set<Date> {
        let calendar = Calendar.current
        return Set(sessions.map { calendar.startOfDay(for: $0.date) })
    }

    /// Get session counts per date (for calendar badges)
    func getSessionCountsByDate() -> [Date: Int] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for session in sessions {
            let startOfDay = calendar.startOfDay(for: session.date)
            counts[startOfDay, default: 0] += 1
        }
        return counts
    }

    /// "Time Reclaimed" aggregates — recomputed fresh from `sessions` on
    /// every call using `Calendar.current`, so day/week boundaries always
    /// reflect the device's current timezone rather than whatever timezone
    /// was active when a session was saved.
    func timeReclaimedSummary() -> TimeReclaimedSummary {
        TimeReclaimed.summary(sessions: sessions, daysLit: stats.daysLit)
    }

    /// Clear all data (for testing/reset)
    func clearAllData() {
        sessions = []
        books = []
        stats = UserStats()
        settings = AppSettings()

        userDefaults.removeObject(forKey: sessionsKey)
        userDefaults.removeObject(forKey: booksKey)
        userDefaults.removeObject(forKey: statsKey)
        userDefaults.removeObject(forKey: settingsKey)

        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()

        // Delete all images
        try? fileManager.removeItem(at: imagesDirectory)
    }
}

// MARK: - UIImage Memory Cost
private extension UIImage {
    /// Approximate decoded size in bytes, for NSCache cost accounting
    var memoryCost: Int {
        guard let cgImage else {
            return Int(size.width * scale * size.height * scale * 4)
        }
        return cgImage.bytesPerRow * cgImage.height
    }
}
