import Foundation
import AVFoundation
import UIKit

/// Service for playing audio sounds
final class AudioService: ObservableObject {

    // MARK: - Singleton
    static let shared = AudioService()

    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var soundEnabled: Bool = true

    // MARK: - Sound Types
    enum Sound: String {
        case bellStart = "bell_start"
        case bellEnd = "185822__lloydevans09__single-chime"

        var filename: String {
            rawValue
        }

        var fileExtension: String {
            switch self {
            case .bellStart:
                return "mp3"
            case .bellEnd:
                return "wav"
            }
        }
    }

    // MARK: - Initialization
    private init() {
        setupAudioSession()
    }

    // MARK: - Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Public Methods
    /// Update sound enabled state
    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
    }

    /// Play a sound
    func play(_ sound: Sound) {
        guard soundEnabled else { return }

        // Try to load from bundle
        if let url = Bundle.main.url(forResource: sound.filename, withExtension: sound.fileExtension) {
            playSound(at: url)
        } else {
            // Fallback: play system sound if custom sound not found
            playSystemSound(for: sound)
        }
    }

    /// Play bell start sound
    func playStartBell() {
        play(.bellStart)
    }

    /// Play bell end sound
    func playEndBell() {
        play(.bellEnd)
    }

    /// Stop any playing sound
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Private Methods
    private func playSound(at url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error)")
        }
    }

    private func playSystemSound(for sound: Sound) {
        // Use system sounds as fallback
        let systemSoundID: SystemSoundID

        switch sound {
        case .bellStart:
            // System sound 1013 is a pleasant chime
            systemSoundID = 1013
        case .bellEnd:
            // System sound 1025 is a completion sound
            systemSoundID = 1025
        }

        AudioServicesPlaySystemSound(systemSoundID)
    }

    /// Play a haptic feedback
    func playHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    /// Play a light impact haptic
    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Audio File Note
/*
 The app expects the following audio files in the Resources/Sounds folder:

 1. bell_start.mp3 - A soft single bell chime to play when the timer begins.
    Suggested: A gentle, meditative bowl or bell sound, ~1-2 seconds.

 2. bell_end.mp3 - A celebratory triple bell chime to play when the timer completes.
    Suggested: Three ascending chimes or a more triumphant bell sequence, ~2-3 seconds.

 If these files are not present, the app will fall back to system sounds.

 You can find royalty-free bell sounds at:
 - freesound.org
 - pixabay.com/sound-effects
 - zapsplat.com

 Make sure to convert to MP3 format and add to the Xcode project target.
 */
