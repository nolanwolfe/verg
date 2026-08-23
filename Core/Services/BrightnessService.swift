import UIKit

/// The one owner of screen brightness.
///
/// Four screens used to manage `UIScreen.main.brightness` independently, each
/// saving "the system value" on appear and restoring it on disappear. Two
/// things went wrong with that:
///
/// 1. Every tab change yanked the brightness — dim on the candle screen, snap
///    back on leaving it, dim again on return.
/// 2. The saved value was captured on appear, which for a screen entered
///    *from* an already-dimmed screen is not the system value at all but the
///    other screen's dim level. Bounce between two of them and the user's
///    real brightness is overwritten and gone for good.
///
/// So brightness is owned here instead. The user's own setting is captured
/// once, before the app first dims anything, and restored only when the app
/// actually goes away — never on a tab change. Inside the app the level the
/// user chose simply persists.
@MainActor
final class BrightnessService: ObservableObject {

    static let shared = BrightnessService()

    /// The device's brightness before Verg touched it. Captured once.
    private var systemBrightness: CGFloat?

    /// What the app is currently holding the screen at, if anything.
    @Published private(set) var level: Double?

    private init() {}

    /// Take control at `level`, remembering the user's own setting the first
    /// time. Safe to call on every appear — repeat calls do not re-capture.
    func take(_ newLevel: Double) {
        if systemBrightness == nil {
            systemBrightness = UIScreen.main.brightness
        }
        set(newLevel)
    }

    /// Adjust while already in control. No-op if the app never took over,
    /// so a stray drag cannot dim the screen without a matching `take`.
    func set(_ newLevel: Double) {
        guard systemBrightness != nil else { return }
        let clamped = max(0.05, min(1.0, newLevel))
        level = clamped
        UIScreen.main.brightness = CGFloat(clamped)
    }

    /// The level a screen should adopt when it appears: whatever the app is
    /// already holding, or its own default if the app holds nothing yet.
    /// This is what keeps brightness steady across a tab change.
    func levelOnAppear(default defaultLevel: Double) -> Double {
        level ?? defaultLevel
    }

    /// Hand the screen back to the user. Called when the app leaves the
    /// foreground — not when a screen is dismissed.
    func relinquish() {
        guard let systemBrightness else { return }
        UIScreen.main.brightness = systemBrightness
        self.systemBrightness = nil
        level = nil
    }

    /// Re-apply the app's level after returning from the background, since
    /// iOS may have changed brightness while away.
    func reapplyAfterForeground() {
        guard let level else { return }
        systemBrightness = systemBrightness ?? UIScreen.main.brightness
        UIScreen.main.brightness = CGFloat(level)
    }
}
