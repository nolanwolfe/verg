import SwiftUI
import UIKit

/// Home screen with candle and begin writing button
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var storageService: StorageService
    @EnvironmentObject private var purchaseService: PurchaseService

    @State private var showTimer = false
    @State private var showPaywall = false

    // Silent brightness control
    @State private var brightness: Double = UIScreen.main.brightness
    @State private var dragStartBrightness: Double = UIScreen.main.brightness

    private let gatingService = SessionGatingService.shared

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()

            // Candle — anchored to top, respects status bar
            VStack(spacing: 0) {
                CandleView(progress: 1.0, isBurning: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .shadow(color: Color(hex: "FF9500").opacity(0.4), radius: 30)
                Spacer()
            }
            .padding(.top, 44)

            // Streak + button — anchored well below candle
            VStack(spacing: 0) {
                Spacer()

                streakSection
                    .padding(.bottom, Theme.Spacing.xl)

                actionButton
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let delta = Double(-value.translation.height) / 300.0
                    brightness = max(0.05, min(1.0, dragStartBrightness + delta))
                    UIScreen.main.brightness = brightness
                }
                .onEnded { _ in
                    dragStartBrightness = brightness
                }
        )
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
            DispatchQueue.main.async {
                viewModel.refresh()
            }
            Task {
                await purchaseService.checkSubscriptionStatus()
            }
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

            Text("🕯️ \(viewModel.sessionsTodayText)")
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
    }

}

// MARK: - Preview
#Preview {
    HomeView()
}
