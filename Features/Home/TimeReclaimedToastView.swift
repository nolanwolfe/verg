import SwiftUI

/// Non-modal "you wrote instead of scrolling" confirmation. Shown once per
/// session on Home after a page is saved — auto-dismisses, never blocks
/// interaction, never nags on a missed day (there's simply nothing to show).
struct TimeReclaimedToastView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "hourglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.Colors.accent)

            Text(message)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .fill(Theme.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Drives auto-dismiss + tap-to-dismiss for a `TimeReclaimedToastView`,
/// hosted as an overlay so it never blocks the screen underneath.
struct TimeReclaimedToastModifier: ViewModifier {
    @Binding var message: String?
    var autoDismissAfter: Double = 4.0

    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                TimeReclaimedToastView(message: message) {
                    dismiss()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear { scheduleAutoDismiss() }
            }
        }
        .animation(Theme.Animation.standard, value: message)
    }

    private func scheduleAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(autoDismissAfter))
            guard !Task.isCancelled else { return }
            await MainActor.run { dismiss() }
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        message = nil
    }
}

extension View {
    /// Shows a dismissible "Time Reclaimed" confirmation pinned to the top
    /// of this view whenever `message` is non-nil, then clears it.
    func timeReclaimedToast(_ message: Binding<String?>) -> some View {
        modifier(TimeReclaimedToastModifier(message: message))
    }
}
