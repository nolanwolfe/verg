import Foundation
import UIKit
import Combine

/// Service for persisting sessions, stats, and settings
final class StorageService: ObservableObject {

    // MARK: - Singleton
    static let shared = StorageService()

    // MARK: - Published Properties
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var stats: UserStats = UserStats()
    @Published var settings: AppSettings = AppSettings()

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default

    private let sessionsKey = "verg.sessions"
    private let statsKey = "verg.stats"
    private let settingsKey = "verg.settings"

    // MARK: - Initialization
    private init() {
        loadAllData()
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
        loadStats()
        loadSettings()

        // Validate streak on load
        stats.validateStreak()
        saveStats()
    }

    private func loadSessions() {
        guard let data = userDefaults.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([Session].self, from: data) else {
            sessions = []
            return
        }
        sessions = decoded.sorted { $0.createdAt > $1.createdAt }
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

    private func saveStats() {
        guard let encoded = try? JSONEncoder().encode(stats) else { return }
        userDefaults.set(encoded, forKey: statsKey)
    }

    func saveSettings() {
        guard let encoded = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(encoded, forKey: settingsKey)
    }

    // MARK: - Session Management
    /// Save a new session with the captured image
    @discardableResult
    func saveSession(image: UIImage, duration: TimeInterval) -> Session? {
        // Generate unique filename
        let filename = "\(UUID().uuidString).jpg"
        let imageURL = imagesDirectory.appendingPathComponent(filename)

        // Compress and save image
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        do {
            try imageData.write(to: imageURL)
        } catch {
            print("Error saving image: \(error)")
            return nil
        }

        // Create session
        let session = Session(
            date: Date(),
            duration: duration,
            imagePath: filename,
            createdAt: Date()
        )

        // Update sessions array
        sessions.insert(session, at: 0)
        saveSessions()

        // Update stats
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

        // Delete image file
        let session = sessions[index]
        let imageURL = imagesDirectory.appendingPathComponent(session.imagePath)
        try? fileManager.removeItem(at: imageURL)

        // Remove from array
        sessions.remove(at: index)
        saveSessions()
    }

    /// Get image for a session
    func getImage(for session: Session) -> UIImage? {
        let imageURL = imagesDirectory.appendingPathComponent(session.imagePath)
        guard let data = try? Data(contentsOf: imageURL) else { return nil }
        return UIImage(data: data)
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

    func setIsSubscribed(_ subscribed: Bool) {
        settings.isSubscribed = subscribed
        saveSettings()
    }

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

    /// Clear all data (for testing/reset)
    func clearAllData() {
        sessions = []
        stats = UserStats()
        settings = AppSettings()

        userDefaults.removeObject(forKey: sessionsKey)
        userDefaults.removeObject(forKey: statsKey)
        userDefaults.removeObject(forKey: settingsKey)

        // Delete all images
        try? fileManager.removeItem(at: imagesDirectory)
    }
}
