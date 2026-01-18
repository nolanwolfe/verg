import SwiftUI

// MARK: - Theme
/// Global design system for the Ink app
/// All UI components should reference these values - no hardcoded styles
enum Theme {

    // MARK: - Colors
    enum Colors {
        static let background = Color(hex: "000000")
        static let cardBackground = Color(hex: "1C1C1E")
        static let primaryText = Color(hex: "FFFFFF")
        static let secondaryText = Color(hex: "8E8E93")
        static let accent = Color(hex: "BF5AF2")

        static let accentGradient = LinearGradient(
            colors: [Color(hex: "BF5AF2"), Color(hex: "FF375F")],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let accentGradientVertical = LinearGradient(
            colors: [Color(hex: "BF5AF2"), Color(hex: "FF375F")],
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
        static let streakDisplay = Font.system(size: 20, weight: .semibold, design: .default)
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
