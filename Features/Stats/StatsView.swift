import SwiftUI

/// Stats screen with pages gallery and calendar
struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with segmented control
                headerSection

                // Content based on selected tab
                tabContent
            }
        }
        .fullScreenCover(isPresented: $viewModel.showFullScreenImage) {
            if let session = viewModel.selectedSession {
                FullScreenImageView(
                    session: session,
                    image: viewModel.getImage(for: session),
                    onDismiss: {
                        viewModel.showFullScreenImage = false
                        viewModel.selectedSession = nil
                    },
                    onDelete: {
                        viewModel.deleteSession(session)
                    }
                )
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Title
            Text("Your Pages")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)

            // Segmented control
            segmentedControl
                .padding(.horizontal, Theme.Spacing.md)
        }
    }

    // MARK: - Segmented Control
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(StatsViewModel.Tab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(Theme.Animation.quick) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(Theme.Typography.subheadline)
                        .fontWeight(viewModel.selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(
                            viewModel.selectedTab == tab
                                ? Theme.Colors.primaryText
                                : Theme.Colors.secondaryText
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(
                            viewModel.selectedTab == tab
                                ? Theme.Colors.cardBackground
                                : Color.clear
                        )
                        .cornerRadius(Theme.CornerRadius.small)
                }
            }
        }
        .padding(Theme.Spacing.xxxs)
        .background(Theme.Colors.background)
        .cornerRadius(Theme.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                .stroke(Theme.Colors.cardBackground, lineWidth: 1)
        )
    }

    // MARK: - Tab Content
    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .pages:
            PageGridView(
                sessions: viewModel.sessions,
                getImage: { viewModel.getImage(for: $0) },
                onSelect: { viewModel.selectSession($0) }
            )

        case .calendar:
            CalendarView(
                currentMonth: $viewModel.currentMonth,
                sessionCountsByDate: viewModel.sessionCountsByDate,
                currentStreak: viewModel.currentStreak,
                totalSessions: viewModel.totalSessions,
                onPreviousMonth: { viewModel.previousMonth() },
                onNextMonth: { viewModel.nextMonth() }
            )
        }
    }
}

// MARK: - Preview
#Preview {
    StatsView()
}
