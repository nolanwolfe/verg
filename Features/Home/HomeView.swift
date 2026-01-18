import SwiftUI

/// Home screen with candle and begin writing button
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showTimer = false

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                // Candle illustration (not burning)
                staticCandleView

                // Streak display
                streakSection

                Spacer()

                // Begin writing button
                actionButton
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .fullScreenCover(isPresented: $showTimer) {
            TimerView(onComplete: {
                showTimer = false
                viewModel.refresh()
            })
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    // MARK: - Static Candle
    private var staticCandleView: some View {
        VStack(spacing: 0) {
            // Wick (no flame)
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.Colors.wickColor)
                .frame(width: 3, height: 20)
                .offset(y: 5)

            // Candle body
            ZStack {
                // Main candle body
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Colors.candleWax,
                                Theme.Colors.candleWaxDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 80, height: 180)

                // Subtle highlight
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .center
                        )
                    )
                    .frame(width: 80, height: 180)
            }
        }
    }

    // MARK: - Streak Section
    private var streakSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(viewModel.streakDisplayText)
                .font(Theme.Typography.streakDisplay)
                .foregroundColor(
                    viewModel.currentStreak > 0
                        ? Theme.Colors.primaryText
                        : Theme.Colors.secondaryText
                )

            Text(viewModel.sessionsTodayText)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    // MARK: - Action Button
    private var actionButton: some View {
        Button {
            showTimer = true
        } label: {
            Text(viewModel.buttonText)
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, Theme.Spacing.lg)
    }

}

// MARK: - Preview
#Preview {
    HomeView()
}
