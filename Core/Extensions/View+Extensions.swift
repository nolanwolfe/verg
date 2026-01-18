import SwiftUI
import UIKit

// MARK: - View Extensions
extension View {

    // MARK: - Theme Modifiers

    /// Apply card background style
    func cardStyle() -> some View {
        self
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
    }

    /// Apply primary button style
    func primaryButtonStyle() -> some View {
        self
            .font(Theme.Typography.headline)
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Layout.buttonHeight)
            .background(Theme.Colors.accentGradient)
            .cornerRadius(Theme.CornerRadius.medium)
    }

    /// Apply secondary button style
    func secondaryButtonStyle() -> some View {
        self
            .font(Theme.Typography.headline)
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Layout.buttonHeight)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.accent, lineWidth: 1)
            )
    }

    // MARK: - Shadow Modifiers

    /// Apply card shadow
    func cardShadow() -> some View {
        self.shadow(
            color: Theme.Shadows.card.color,
            radius: Theme.Shadows.card.radius,
            x: Theme.Shadows.card.x,
            y: Theme.Shadows.card.y
        )
    }

    /// Apply button glow shadow
    func buttonGlow() -> some View {
        self.shadow(
            color: Theme.Shadows.button.color,
            radius: Theme.Shadows.button.radius,
            x: Theme.Shadows.button.x,
            y: Theme.Shadows.button.y
        )
    }

    /// Apply flame glow effect
    func flameGlow() -> some View {
        self.shadow(
            color: Theme.Shadows.glow.color,
            radius: Theme.Shadows.glow.radius,
            x: Theme.Shadows.glow.x,
            y: Theme.Shadows.glow.y
        )
    }

    // MARK: - Layout Helpers

    /// Fill available width
    func fillWidth(alignment: Alignment = .center) -> some View {
        self.frame(maxWidth: .infinity, alignment: alignment)
    }

    /// Fill available height
    func fillHeight(alignment: Alignment = .center) -> some View {
        self.frame(maxHeight: .infinity, alignment: alignment)
    }

    /// Fill available space
    func fill(alignment: Alignment = .center) -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    // MARK: - Conditional Modifiers

    /// Apply modifier conditionally
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Apply modifier conditionally with else clause
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }

    // MARK: - Hide Keyboard

    /// Hide keyboard on tap
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }

    // MARK: - Debug

    /// Add debug border (useful during development)
    func debugBorder(_ color: Color = .red) -> some View {
        #if DEBUG
        return self.border(color)
        #else
        return self
        #endif
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Layout.buttonHeight)
            .background(
                Group {
                    if isEnabled {
                        Theme.Colors.accentGradient
                    } else {
                        Theme.Colors.cardBackground
                    }
                }
            )
            .cornerRadius(Theme.CornerRadius.medium)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
            .buttonGlow()
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundColor(Theme.Colors.accent)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Layout.buttonHeight)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.accent, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.Animation.quick, value: configuration.isPressed)
    }
}

struct TextLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.subheadline)
            .foregroundColor(Theme.Colors.secondaryText)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - View Extension for Button Styles
extension View {
    func asPrimaryButton(isEnabled: Bool = true) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isEnabled: isEnabled))
    }

    func asSecondaryButton() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }

    func asTextLink() -> some View {
        self.buttonStyle(TextLinkButtonStyle())
    }
}
