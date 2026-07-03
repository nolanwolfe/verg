import SwiftUI

/// Stats screen — streak, totals, and writing calendar
struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

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
        .onAppear {
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
}

// MARK: - Preview
#Preview {
    StatsView()
}
