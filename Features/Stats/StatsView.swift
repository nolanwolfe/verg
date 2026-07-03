import SwiftUI
import UIKit

/// Stats screen — swipeable stat cards and writing calendar
struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State private var currentCard = 0
    @State private var showMilestones = false

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.md) {
                        statCarousel

                        CalendarView(
                            currentMonth: $viewModel.currentMonth,
                            sessionCountsByDate: viewModel.sessionCountsByDate,
                            onPreviousMonth: { viewModel.previousMonth() },
                            onNextMonth: { viewModel.nextMonth() }
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
            }
        }
        .onAppear {
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(Theme.Colors.accent)
            UIPageControl.appearance().pageIndicatorTintColor = UIColor(Theme.Colors.secondaryText.opacity(0.3))
            DispatchQueue.main.async {
                viewModel.refresh()
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        Text("Stats")
            .font(Theme.Typography.title)
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)
    }

    // MARK: - Stat Carousel
    private var statCarousel: some View {
        TabView(selection: $currentCard) {
            BigStatCard(
                title: "Current Streak",
                value: "\(viewModel.currentStreak)",
                unit: viewModel.currentStreak == 1 ? "day" : "days"
            ) {
                StreakFlameIcon(size: 20)
            }
            .tag(0)

            BigStatCard(
                title: "Total Pages",
                value: "\(viewModel.totalSessions)",
                unit: viewModel.totalSessions == 1 ? "page" : "pages"
            ) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(Theme.Colors.accent)
                    .font(.system(size: 20))
            }
            .tag(1)

            BigStatCard(
                title: "Longest Streak",
                value: "\(viewModel.longestStreak)",
                unit: viewModel.longestStreak == 1 ? "day" : "days"
            ) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(Color(hex: "FFCC00"))
                    .font(.system(size: 20))
            }
            .tag(2)

            milestoneCard
                .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 170)
        .sheet(isPresented: $showMilestones) {
            MilestonesView(totalSessions: viewModel.totalSessions)
        }
    }

    // MARK: - Milestone Card
    private var milestoneCard: some View {
        Button {
            showMilestones = true
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "rosette")
                        .foregroundColor(Color(hex: "FF9500"))
                        .font(.system(size: 20))

                    Text("Milestones")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.secondaryText.opacity(0.5))
                }

                if let next = Milestone.nextMilestone(after: viewModel.totalSessions) {
                    Text("\(viewModel.totalSessions) / \(next.threshold) pages")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.primaryText)

                    ProgressView(value: Milestone.progress(totalSessions: viewModel.totalSessions))
                        .tint(Theme.Colors.accent)

                    Text("Next: \(next.title)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                } else {
                    Text("All milestones unlocked!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.medium)
            .padding(.bottom, 28) // room for page dots
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Big Stat Card
/// Full-width swipeable stat card for the stats carousel
struct BigStatCard<Icon: View>: View {
    let title: String
    let value: String
    let unit: String
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                icon()

                Text(title)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                Text(value)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.primaryText)

                Text(unit)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .padding(.bottom, 28) // room for page dots
    }
}

// MARK: - Preview
#Preview {
    StatsView()
}
