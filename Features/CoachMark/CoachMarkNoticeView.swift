import SwiftUI

/// Reusable coach-mark notice modal component
/// Displays a title, body text, and one or two action buttons
struct CoachMarkNoticeView: View {
    let title: String
    let message: String
    let primaryButtonText: String
    var secondaryButtonText: String? = nil

    var onPrimaryTap: () -> Void
    var onSecondaryTap: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissing by tapping outside
                }

            // Notice card
            VStack(spacing: Theme.Spacing.lg) {
                // Title
                Text(title)
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.center)

                // Body text
                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // Buttons
                VStack(spacing: Theme.Spacing.sm) {
                    // Primary button
                    Button {
                        onPrimaryTap()
                    } label: {
                        Text(primaryButtonText)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    // Secondary button (optional)
                    if let secondaryText = secondaryButtonText,
                       let secondaryAction = onSecondaryTap {
                        Button {
                            secondaryAction()
                        } label: {
                            Text(secondaryText)
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        .padding(.top, Theme.Spacing.xxs)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .fill(Theme.Colors.cardBackground)
            )
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .transition(.opacity)
    }
}

// MARK: - Preview
#Preview("Start Timer Notice") {
    CoachMarkNoticeView(
        title: AppStrings.CoachMark.StartTimer.title,
        message: AppStrings.CoachMark.StartTimer.body,
        primaryButtonText: AppStrings.CoachMark.StartTimer.primaryButton,
        secondaryButtonText: AppStrings.CoachMark.StartTimer.secondaryButton,
        onPrimaryTap: {},
        onSecondaryTap: {}
    )
}

#Preview("Upload Photo Notice") {
    CoachMarkNoticeView(
        title: AppStrings.CoachMark.UploadPhoto.title,
        message: AppStrings.CoachMark.UploadPhoto.body,
        primaryButtonText: AppStrings.CoachMark.UploadPhoto.primaryButton,
        secondaryButtonText: AppStrings.CoachMark.UploadPhoto.secondaryButton,
        onPrimaryTap: {},
        onSecondaryTap: {}
    )
}
