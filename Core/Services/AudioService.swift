import Foundation
import AVFoundation
import UIKit

/// Service for playing audio sounds
final class AudioService: ObservableObject {

    // MARK: - Singleton
    static let shared = AudioService()

    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var ambientPlayer: AVAudioPlayer?
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

    // MARK: - Ambient Sounds
    /// Looping ambience played during writing sessions (Pro feature)
    enum AmbientSound: String, CaseIterable, Identifiable {
        case rain
        case fireplace = "fire"
        case deepFocus = "focus"
        case replenish
        case motion
        case floating
        case earth
        case deep
        case movement
        case storm
        case stream

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .rain: return "Rain"
            case .fireplace: return "Fireplace"
            case .deepFocus: return "Deep Focus"
            case .replenish: return "Replenish"
            case .motion: return "Motion"
            case .floating: return "Floating"
            case .earth: return "Earth"
            case .deep: return "The Deep"
            case .movement: return "Movement"
            case .storm: return "Storm"
            case .stream: return "Stream"
            }
        }

        var icon: String {
            switch self {
            case .rain: return "cloud.rain.fill"
            case .fireplace: return "flame.fill"
            case .deepFocus: return "waveform"
            case .replenish: return "drop.fill"
            case .motion: return "wind"
            case .floating: return "cloud.fill"
            case .earth: return "leaf.fill"
            case .deep: return "moon.stars.fill"
            case .movement: return "sparkles"
            case .storm: return "cloud.bolt.rain.fill"
            case .stream: return "water.waves"
            }
        }

        var filename: String { "ambient_\(rawValue)" }

        /// The three original loops are short uncompressed PCM .caf clips;
        /// the newer, much longer tracks are AAC .m4a (compressed — some run
        /// 10-35 minutes, and uncompressed at that length would be enormous).
        var fileExtension: String {
            switch self {
            case .rain, .fireplace, .deepFocus: return "caf"
            default: return "m4a"
            }
        }
    }

    // MARK: - Initialization
    private init() {
        setupAudioSession()
        // Mirror the persisted preference at launch — without this the
        // service starts assuming sound is on regardless of the setting.
        soundEnabled = StorageService.shared.settings.soundEnabled
    }

    // MARK: - Setup
    // .ambient (not .playback): respects the silent switch — if someone has
    // deliberately silenced their phone, an app about quiet doesn't get to
    // override that. Trade-off: .ambient doesn't survive true backgrounding
    // (only .playback does, and only with the Audio background mode, which
    // this app doesn't declare). In practice the session stays foreground
    // the whole time — the ritual is "face down," not "backgrounded" —
    // .mixWithOthers still means it never interrupts other audio.
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    /// Re-activate the session after the app has been in the background.
    ///
    /// `.ambient` is deactivated by the system when the app backgrounds, and
    /// nothing brought it back — it was activated once in `init` and never
    /// again. So a single trip to the home screen or the app switcher left
    /// the session inactive for the rest of the process, and every later
    /// attempt at ambience played into a dead session: no error, no log,
    /// just silence. Cheap to call, and a no-op when already active.
    func reactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("AudioService: could not reactivate session — \(error)")
            #endif
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

    /// Start a looping ambient track with a gentle fade-in
    func startAmbience(_ sound: AmbientSound) {
        guard let url = Bundle.main.url(forResource: sound.filename, withExtension: sound.fileExtension) else {
            #if DEBUG
            print("AudioService: missing ambient sound \(sound.filename).\(sound.fileExtension)")
            #endif
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            player.play()
            player.setVolume(0.55, fadeDuration: 1.5)
            ambientPlayer = player
        } catch {
            print("Failed to start ambience: \(error)")
        }
    }

    /// Fade out and stop the ambient track
    func stopAmbience(fadeOut: TimeInterval = 1.0) {
        guard let player = ambientPlayer else { return }
        ambientPlayer = nil
        player.setVolume(0, fadeDuration: fadeOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut + 0.1) {
            player.stop()
        }
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

    /// The small tick used for interface actions — switching tabs, flipping
    /// a setting. Haptic always, sound only when the user has sound on, so
    /// the Sound switch in Settings governs the whole interface, not just
    /// the bells. System sound 1104 is the keyboard tick: short and dry,
    /// which is what this wants — nothing here should feel like a chime.
    func playUITick(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        playImpact(style)
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(1104)
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
