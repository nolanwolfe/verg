import SwiftUI
import UIKit

/// Stats screen — swipeable stat cards and writing calendar. Warmed to
/// match the candle/celebration visual language used elsewhere (gradient
/// icons, soft glow) rather than flat system-style cards, since this is
/// meant to be a screen people actually want to open.
struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State private var currentCard = 0
    @State private var showMilestones = false

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ambientGlow

            VStack(spacing: 0) {
                headerSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.md) {
                        statCarousel

                        timeReclaimedWeekCard

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

    // MARK: - Ambient Glow
    /// Same warm radial language as the timer/celebration screens, just
    /// dialed way down — this isn't a celebration moment, just a reminder
    /// this app is one whole thing, not a utility bolted onto a journal.
    private var ambientGlow: some View {
        RadialGradient(
            colors: [
                Color(hex: "FF9500").opacity(0.10),
                Color(hex: "FF7000").opacity(0.04),
                Color.clear
            ],
            center: UnitPoint(x: 0.5, y: 0),
            startRadius: 10,
            endRadius: 380
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Your Progress")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.primaryText)

            Text(headerSubtitle)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.md)
    }

    /// Neutral and factual either way — never a nag on a quiet stretch.
    private var headerSubtitle: String {
        viewModel.totalSessions == 0
            ? "Every page starts here."
            : "\(viewModel.totalSessions) \(viewModel.totalSessions == 1 ? "page" : "pages") and counting."
    }

    // MARK: - Stat Carousel
    private var statCarousel: some View {
        TabView(selection: $currentCard) {
            BigStatCard(
                title: "Current Streak",
                value: "\(viewModel.currentStreak)",
                unit: viewModel.currentStreak == 1 ? "day" : "days"
            ) {
                warmIcon("flame.fill")
            }
            .tag(0)

            BigStatCard(
                title: "Total Pages",
                value: "\(viewModel.totalSessions)",
                unit: viewModel.totalSessions == 1 ? "page" : "pages"
            ) {
                warmIcon("doc.text.fill")
            }
            .tag(1)

            BigStatCard(
                title: "Longest Streak",
                value: "\(viewModel.longestStreak)",
                unit: viewModel.longestStreak == 1 ? "day" : "days"
            ) {
                warmIcon("trophy.fill")
            }
            .tag(2)

            BigStatCard(
                title: "Time Reclaimed",
                value: formattedDuration(minutes: viewModel.timeReclaimed.allTimeMinutes),
                unit: "written"
            ) {
                warmIcon("hourglass")
            }
            .tag(3)

            if viewModel.weeklyCommitmentDaysPerWeek != nil {
                weeklyGoalCard
                    .tag(4)
            }

            milestoneCard
                .tag(5)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 170)
        .sheet(isPresented: $showMilestones) {
            MilestonesView(totalSessions: viewModel.totalSessions)
        }
    }

    /// Icon treatment shared by every carousel card — the same warm
    /// gradient + glow used on the milestone/Time Reclaimed reveal screens.
    private func warmIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "FFCC00"), Color(hex: "FF9500")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Color(hex: "FF9500").opacity(0.35), radius: 6)
    }

    // MARK: - Weekly Goal Card
    /// Only shown once a commitment exists — progress toward the next
    /// goal-adherence milestone, the stats-tab half of the loop that
    /// closes in TimerViewModel's celebration sequencing.
    private var weeklyGoalCard: some View {
        let goalDays = viewModel.weeklyCommitmentDaysPerWeek ?? 0
        return Button {
            showMilestones = true
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.xs) {
                    warmIcon("target")
                    Text("Weekly Goal")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Spacer()
                }

                if let next = WeeklyGoalMilestone.nextMilestone(after: viewModel.weeksGoalMet) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                        Text("\(viewModel.weeksGoalMet)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("of \(next.weeksThreshold) weeks at \(goalDays)/wk")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                } else {
                    Text("All goal milestones unlocked!")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
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

    // MARK: - Time Reclaimed Week Card
    private var timeReclaimedWeekCard: some View {
        let summary = viewModel.timeReclaimed
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                warmIcon("hourglass")

                Text("This Week")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)

                Spacer()

                if summary.streak > 0 {
                    HStack(spacing: 3) {
                        StreakFlameIcon(size: 13)
                        Text("\(summary.streak) \(summary.streak == 1 ? "day" : "days")")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
            }

            Text(formattedDuration(minutes: summary.weekMinutes))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.primaryText)

            Text(weekDeltaText(summary))
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    /// Factual, neutral phrasing — never editorializes on a down week.
    private func weekDeltaText(_ summary: TimeReclaimedSummary) -> String {
        let delta = summary.weekDeltaMinutes
        if summary.lastWeekSeconds == 0 && summary.weekSeconds == 0 {
            return "No pages yet this week"
        } else if delta == 0 {
            return "Same as last week"
        } else if delta > 0 {
            return "+\(delta) min vs. last week"
        } else {
            return "\(delta) min vs. last week"
        }
    }

    private func formattedDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins) min"
    }

    // MARK: - Milestone Card
    private var milestoneCard: some View {
        Button {
            showMilestones = true
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.xs) {
                    warmIcon("rosette")

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
