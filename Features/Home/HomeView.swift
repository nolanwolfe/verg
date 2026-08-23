import SwiftUI
import UIKit

/// Home screen with candle and begin writing button
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var storageService: StorageService
    @EnvironmentObject private var purchaseService: PurchaseService

    @State private var showTimer = false
    @State private var showDurationPicker = false
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
                CandleView(progress: 1.0, isBurning: true, daysLit: viewModel.daysLit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .shadow(color: Theme.Colors.flameOuter.opacity(0.4), radius: 30)
                Spacer()
            }
            .padding(.top, 44)

            // Days lit + button — anchored well below candle
            VStack(spacing: 0) {
                Spacer()

                daysLitSection
                    .padding(.bottom, Theme.Spacing.xl)

                actionButton

                durationPill
                    .padding(.top, Theme.Spacing.sm)
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
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerSheet(
                currentDuration: storageService.settings.timerDuration,
                onSelect: { duration in
                    guard duration == AppSettings.defaultTimerDuration || gatingService.isPremium else {
                        showDurationPicker = false
                        showPaywall = true
                        return
                    }
                    storageService.setTimerDuration(duration)
                    showDurationPicker = false
                },
                onDone: { showDurationPicker = false }
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(purchaseService)
        }
        .fullScreenCover(isPresented: $showTimer) {
            TimerView(onComplete: { _ in
                showTimer = false
                viewModel.refresh()
                presentSessionPaywallIfEarned()
            })
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
    // Writing is always free and unlimited — the paywall only gates saving
    // a page beyond the free allotment (see CameraViewModel.usePhoto()).
    private func attemptStartSession() {
        showTimer = true
    }

    /// The paywall's one unprompted appearance: once, on returning from the
    /// session that produced the seventh saved page. It used to sit at the
    /// end of onboarding, before the user had written anything; here they
    /// have seven pages and the offer is about keeping them.
    ///
    /// Deliberately after the timer screen has closed, so it never lands on
    /// top of a milestone celebration or the Time Reclaimed reveal.
    private func presentSessionPaywallIfEarned() {
        guard !gatingService.isPremium,
              !storageService.settings.hasSeenSessionPaywall,
              storageService.stats.totalSessions >= 7
        else { return }

        storageService.setHasSeenSessionPaywall(true)
        // A beat after dismissal, or the two full-screen covers collide.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showPaywall = true
        }
    }

    // MARK: - Days Lit Section
    private var daysLitSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                if viewModel.daysLit > 0 {
                    CandleFlameIcon()
                }
                Text(viewModel.daysLitDisplayText)
                    .font(Theme.Typography.daysLitDisplay)
                    .foregroundColor(
                        viewModel.daysLit > 0
                            ? Theme.Colors.primaryText
                            : Theme.Colors.secondaryText
                    )
            }

            Text("\(viewModel.sessionsTodayText)")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    // MARK: - Duration Pill
    private var durationPill: some View {
        Button {
            showDurationPicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .medium))
                Text(storageService.settings.shortFormattedDuration)
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(Theme.Colors.secondaryText)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(
                Capsule()
                    .stroke(Theme.Colors.secondaryText.opacity(0.25), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
