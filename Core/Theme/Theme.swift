import SwiftUI
import UIKit

// MARK: - Theme
/// Global design system for the Ink app
/// All UI components should reference these values - no hardcoded styles
enum Theme {

    // MARK: - Colors
    ///
    /// Every token below is a *dynamic* colour: it resolves against whatever
    /// interface style it is drawn in, so the light theme arrives without a
    /// single call site changing. Setting the root's colour scheme is enough.
    ///
    /// This is also why the ritual screens can opt out cheaply — Verg, the
    /// writing timer and the camera pin themselves to `.dark`, and the same
    /// tokens then resolve dark there no matter what the rest of the app is
    /// doing. Those screens dim the physical display on purpose; a white
    /// candle screen would undo the point of them.
    enum Colors {
        /// Resolves `dark` in dark mode, `light` otherwise.
        static func adaptive(light: String, dark: String) -> Color {
            Color(UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            })
        }

        static let background = adaptive(light: "FAF7F0", dark: "000000")
        static let cardBackground = adaptive(light: "FFFFFF", dark: "1C1C1E")
        static let primaryText = adaptive(light: "17140E", dark: "FFFFFF")
        static let secondaryText = adaptive(light: "6E675C", dark: "8E8E93")
        /// Section labels and the faintest supporting text. Was written as
        /// `.white.opacity(0.4)` in a dozen places, which is invisible on
        /// paper — hence a token.
        static let tertiaryText = adaptive(light: "9A9187", dark: "6E6E73")
        /// Separator lines and card outlines.
        static let hairline = adaptive(light: "E3DCCE", dark: "2C2C2E")
        /// The barely-there fill behind grouped rows and grid cells.
        static let subtleFill = adaptive(light: "00000008", dark: "FFFFFF0A")

        /// Gold. Replaces the old `systemPurple`, which was Apple's stock
        /// value unmodified and sat cold against a candlelit app — every
        /// screen had a warm centre and a cool frame. Gold belongs to the
        /// flame without competing with it, and it was already half-present
        /// in the achievement stars and The Golden Age, so the paid tier's
        /// colour is now the product's colour.
        ///
        /// Reads expensive as a line and cheap as a slab: keep it to icons,
        /// rules, small type, and thin strokes. Large fills stay cream.
        /// Darker in light mode: #D4AF37 on paper is about 2:1 against
        /// white, which fails as text or as an icon. The deeper value keeps
        /// the same hue and clears contrast on both grounds.
        static let accent = adaptive(light: "8A6D1E", dark: "D4AF37")
        /// Lifted gold for text on the accent, and for the brighter stop of
        /// a gradient.
        static let accentLight = adaptive(light: "B08F2E", dark: "F2E3A6")
        /// Recessed gold for gradient bottoms and pressed states.
        static let accentDeep = adaptive(light: "5E4A12", dark: "8A6D1E")

        /// Switches only. Deliberately Apple's system blue rather than the
        /// app accent: a toggle is a system affordance, and people read blue
        /// as "on" without being taught. Gold switches also read as
        /// decoration rather than state.
        static let toggleTint = Color.blue

        /// The primary button's fill. Inverts with the theme: wax cream on
        /// black, ink on paper. Left as cream in light mode it was a
        /// cream button on a cream page — the most important control in the
        /// app, invisible.
        static let buttonFill = adaptive(light: "17140E", dark: "F7F1E2")
        /// Text on `buttonFill`.
        static let buttonLabel = adaptive(light: "FAF7F0", dark: "000000")

        static let accentGradient = LinearGradient(
            colors: [buttonFill, buttonFill],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let accentGradientVertical = LinearGradient(
            colors: [buttonFill, buttonFill],
            startPoint: .top,
            endPoint: .bottom
        )

        // Candle colors
        static let candleWax = Color(hex: "FFF8E7")
        static let candleWaxDark = Color(hex: "E8DCC8")
        static let flameOuter = Color(hex: "FF9500")
        static let flameInner = Color(hex: "FFCC00")
        static let flameCore = Color(hex: "FFFFFF")
        static let wickColor = Color(hex: "2C2C2E")
        static let glowColor = Color(hex: "FF9500").opacity(0.3)
    }

    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)

        // Timer specific
        static let timerDisplay = Font.system(size: 48, weight: .light, design: .monospaced)
        static let daysLitDisplay = Font.system(size: 20, weight: .semibold, design: .default).monospacedDigit()
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxxs: CGFloat = 4
        static let xxs: CGFloat = 8
        static let xs: CGFloat = 12
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
        static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum CornerRadius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 24
    }

    // MARK: - Shadows
    enum Shadows {
        static let card = Shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        static let button = Shadow(color: Colors.accent.opacity(0.4), radius: 12, x: 0, y: 4)
        static let glow = Shadow(color: Colors.flameOuter.opacity(0.5), radius: 20, x: 0, y: 0)
    }

    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
        static let flicker = SwiftUI.Animation.easeInOut(duration: 0.15)
    }

    // MARK: - Layout
    enum Layout {
        static let maxContentWidth: CGFloat = 400
        static let buttonHeight: CGFloat = 56
        static let tabBarHeight: CGFloat = 83
        static let iconSize: CGFloat = 24
        static let smallIconSize: CGFloat = 20
        static let largeIconSize: CGFloat = 32
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - UIColor Hex
/// Backs `Theme.Colors.adaptive`. UIKit is the only route to a colour that
/// resolves per trait collection, which is what lets one token serve both
/// themes without touching call sites.
extension UIColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            // RRGGBBAA — alpha last, matching how the tokens above are written.
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
