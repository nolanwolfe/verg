import SwiftUI

/// Home screen with candle and begin writing button
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var storageService: StorageService
    @EnvironmentObject private var purchaseService: PurchaseService

    @State private var showTimer = false
    @State private var showPaywall = false

    private let gatingService = SessionGatingService.shared

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
        .fullScreenCover(isPresented: $showPaywall, onDismiss: {
            // Refresh after paywall closes to check subscription status
            viewModel.refresh()
        }) {
            PaywallView(onSubscribed: {
                // User subscribed - dismiss paywall and start session
                showPaywall = false
                // Start timer after brief delay to let paywall dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showTimer = true
                }
            })
            .environmentObject(purchaseService)
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    // MARK: - Session Start Logic
    private func attemptStartSession() {
        // Log gating status for debugging
        gatingService.logGatingStatus()

        if gatingService.canStartSession {
            showTimer = true
        } else {
            // User has exceeded free session limit - show paywall
            showPaywall = true
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
            attemptStartSession()
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
