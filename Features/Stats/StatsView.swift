import SwiftUI
import UIKit

/// Stats screen — swipeable stat cards and writing calendar. Warmed to
/// match the candle/celebration visual language used elsewhere (gradient
/// icons, soft glow) rather than flat system-style cards, since this is
/// meant to be a screen people actually want to open.
struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @EnvironmentObject private var purchaseService: PurchaseService
    @State private var currentCard = 0
    @State private var showMilestones = false
    @State private var showPaywall = false

    private let gatingService = SessionGatingService.shared

    /// Free per the business model: the ritual, days lit, and the
    /// calendar. Everything else in Stats (page count, longest run, Time
    /// Reclaimed, weekly goal, milestones) is Ascent.
    private var isStatsLocked: Bool { !gatingService.isPremium }

    var body: some View {
        GeometryReader { geo in
            // One screen, no scroll. If everything doesn't fit, the This
            // Week / locked-feature card is the first thing cut — the
            // stat carousel and calendar are the core display and always
            // show in full.
            let isCompact = geo.size.height < 700

            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                ambientGlow

                VStack(spacing: Theme.Spacing.xs) {
                    headerSection

                    statCarousel

                    if !isCompact {
                        if isStatsLocked {
                            LockedFeatureCard(
                                icon: "chart.bar.fill",
                                title: "Time Reclaimed & more",
                                message: "Writing time, weekly pace, and milestones.",
                                onTap: { showPaywall = true }
                            )
                        } else {
                            timeReclaimedWeekCard
                        }
                    }

                    CalendarView(
                        currentMonth: $viewModel.currentMonth,
                        sessionCountsByDate: viewModel.sessionCountsByDate,
                        relitDates: viewModel.relitDates,
                        onPreviousMonth: { viewModel.previousMonth() },
                        onNextMonth: { viewModel.nextMonth() },
                        compact: isCompact
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(purchaseService)
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
                Theme.Colors.flameOuter.opacity(0.10),
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
        .padding(.top, Theme.Spacing.sm)
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
                title: "Days Lit",
                value: "\(viewModel.daysLit)",
                unit: viewModel.daysLit == 1 ? "day" : "days"
            ) {
                warmIcon("flame.fill")
            }
            .tag(0)

            lockableCard(tag: 1) {
                BigStatCard(
                    title: "Total Pages",
                    value: "\(viewModel.totalSessions)",
                    unit: viewModel.totalSessions == 1 ? "page" : "pages"
                ) {
                    warmIcon("doc.text.fill")
                }
            }

            lockableCard(tag: 2) {
                BigStatCard(
                    title: "Longest Run",
                    value: "\(viewModel.longestDaysLit)",
                    unit: viewModel.longestDaysLit == 1 ? "day" : "days"
                ) {
                    warmIcon("trophy.fill")
                }
            }

            lockableCard(tag: 3) {
                BigStatCard(
                    title: "Time Reclaimed",
                    value: formattedDuration(minutes: viewModel.timeReclaimed.allTimeMinutes),
                    unit: "written"
                ) {
                    warmIcon("hourglass")
                }
            }

            if viewModel.weeklyCommitmentDaysPerWeek != nil {
                lockableCard(tag: 4) { weeklyGoalCard }
            }

            lockableCard(tag: 5) { milestoneCard }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 170)
        .sheet(isPresented: $showMilestones) {
            MilestonesView(totalSessions: viewModel.totalSessions)
        }
    }

    /// Wraps a carousel card with the lock overlay when stats are locked —
    /// the card's shape/size still reserves its place in the swipe
    /// sequence, it just can't be read or interacted with.
    ///
    /// The wrapped content (BigStatCard/weeklyGoalCard/milestoneCard)
    /// already carries its own bottom padding for the page-dot indicator
    /// below the TabView frame — this used to add a second, identical
    /// padding on top of it, doubling to 56pt and visibly misaligning
    /// every locked card against the always-unlocked Days Lit card. Fixed:
    /// this wrapper adds none of its own.
    @ViewBuilder
    private func lockableCard<Content: View>(tag: Int, @ViewBuilder content: () -> Content) -> some View {
        if isStatsLocked {
            content()
                .redacted(reason: .placeholder)
                .overlay(
                    Button { showPaywall = true } label: {
                        VStack(spacing: Theme.Spacing.xxs) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.Colors.primaryText)
                            Text("Included with The Ascent.")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.background.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
                    }
                    .buttonStyle(.plain)
                )
                .tag(tag)
        } else {
            content()
                .tag(tag)
        }
    }

    /// Icon treatment shared by every carousel card — the same warm
    /// gradient + glow used on the milestone/Time Reclaimed reveal screens.
    private func warmIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20))
            .foregroundStyle(
                LinearGradient(
                    colors: [Theme.Colors.flameInner, Theme.Colors.flameOuter],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Theme.Colors.flameOuter.opacity(0.35), radius: 6)
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
                    Text("All goal milestones unlocked.")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
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

                if summary.daysLit > 0 {
                    HStack(spacing: 3) {
                        CandleFlameIcon(size: 13)
                        Text("\(summary.daysLit) \(summary.daysLit == 1 ? "day" : "days")")
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
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
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
                    Text("All milestones unlocked.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
        .padding(.bottom, 28) // room for page dots
    }
}

// MARK: - Locked Feature Card
/// Shared "here's what this is, upgrade to unlock" card — never a blank
/// screen or silent no-op for a gated feature. Reused wherever a whole
/// section (not just a stray tap) is behind a subscription.
struct LockedFeatureCard: View {
    let icon: String
    let title: String
    let message: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.Colors.flameInner, Theme.Colors.flameOuter],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    Text(message)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.secondaryText.opacity(0.6))
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    StatsView()
}
