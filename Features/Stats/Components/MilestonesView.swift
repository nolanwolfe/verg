import SwiftUI

/// Badge grid of all page milestones — unlocked ones glow, locked ones dim
struct MilestonesView: View {
    @ObservedObject private var achievementService = AchievementService.shared
    @Environment(\.dismiss) private var dismiss

    let totalSessions: Int

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                        ForEach(Milestone.all) { milestone in
                            MilestoneBadge(
                                milestone: milestone,
                                isUnlocked: achievementService.isUnlocked(milestone)
                            )
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle("Milestones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
    }
}

// MARK: - Milestone Badge
struct MilestoneBadge: View {
    let milestone: Milestone
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        isUnlocked
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Theme.Colors.flameOuter, Color(hex: "FF4500")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            : AnyShapeStyle(Theme.Colors.cardBackground)
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: isUnlocked ? milestone.icon : "lock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(
                        isUnlocked ? .white : Theme.Colors.secondaryText.opacity(0.5)
                    )
            }
            .shadow(
                color: isUnlocked ? Theme.Colors.flameOuter.opacity(0.4) : .clear,
                radius: 12
            )

            Text(milestone.title)
                .font(Theme.Typography.subheadline)
                .foregroundColor(
                    isUnlocked ? Theme.Colors.primaryText : Theme.Colors.secondaryText
                )

            Text(isUnlocked ? "Unlocked" : "\(milestone.threshold) pages")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.cardBackground.opacity(isUnlocked ? 1.0 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium, style: .continuous))
    }
}

// MARK: - Preview
#Preview {
    MilestonesView(totalSessions: 117)
}
