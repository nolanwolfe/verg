import SwiftUI

/// Main content view with tab navigation
struct ContentView: View {
    @EnvironmentObject private var storageService: StorageService
    @EnvironmentObject private var purchaseService: PurchaseService

    @State private var selectedTab: Tab = .write
    @State private var showOnboarding: Bool = true
    @State private var showStartTimerNotice: Bool = false
    @State private var showTimerFromNotice: Bool = false

    enum Tab: String {
        case write
        case journal
        case verg
        case stats
        case settings
    }

    var body: some View {
        ZStack {
            // Main app is always the base layer
            mainTabView

            // Onboarding overlay (first launch only)
            if showOnboarding && !storageService.settings.hasSeenOnboarding {
                OnboardingView(onComplete: {
                    // Defer state changes to avoid "Publishing changes from within view updates"
                    DispatchQueue.main.async {
                        showOnboarding = false
                        handleOnboardingComplete()
                    }
                })
                .transition(.opacity)
            }

            // "Start the timer" coach mark notice (after onboarding, first time only)
            if showStartTimerNotice {
                CoachMarkNoticeView(
                    title: AppStrings.CoachMark.StartTimer.title,
                    message: AppStrings.CoachMark.StartTimer.body,
                    primaryButtonText: AppStrings.CoachMark.StartTimer.primaryButton,
                    secondaryButtonText: AppStrings.CoachMark.StartTimer.secondaryButton,
                    onPrimaryTap: {
                        // "Start session" - navigate to timer
                        DispatchQueue.main.async {
                            handleStartSessionTapped()
                        }
                    },
                    onSecondaryTap: {
                        // "Not now" - just dismiss
                        DispatchQueue.main.async {
                            handleNotNowTapped()
                        }
                    }
                )
                .zIndex(1)
            }
        }
        .fullScreenCover(isPresented: $showTimerFromNotice) {
            TimerView(onComplete: { _ in
                showTimerFromNotice = false
            })
        }
        .onAppear {
            checkSubscriptionStatus()
        }
    }

    // MARK: - Onboarding Flow Handlers

    private func handleOnboardingComplete() {
        // Show the "Start the timer" notice after onboarding (first time only)
        if !storageService.settings.hasSeenSetTimerNotice {
            withAnimation(Theme.Animation.standard) {
                showStartTimerNotice = true
            }
        }
        // If already seen, just go to home (no paywall here - paywall shows on 4th session attempt)
    }

    private func handleStartSessionTapped() {
        // Mark notice as seen
        storageService.setHasSeenSetTimerNotice(true)

        // Dismiss notice and navigate to timer
        withAnimation(Theme.Animation.standard) {
            showStartTimerNotice = false
        }

        // Show timer after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showTimerFromNotice = true
        }
    }

    private func handleNotNowTapped() {
        // Mark notice as seen
        storageService.setHasSeenSetTimerNotice(true)

        // Just dismiss - user goes to home
        withAnimation(Theme.Animation.standard) {
            showStartTimerNotice = false
        }
    }

    // MARK: - Subscription Check
    private func checkSubscriptionStatus() {
        Task {
            _ = await purchaseService.checkSubscriptionStatus()
        }
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        currentTabContent
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(selectedTab: $selectedTab)
            }
    }

    @ViewBuilder
    private var currentTabContent: some View {
        switch selectedTab {
        case .write:
            HomeView()
        case .journal:
            JournalView()
        case .verg:
            VergFlameView()
                .ignoresSafeArea()
        case .stats:
            StatsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(StorageService.shared)
        .environmentObject(PurchaseService.shared)
}
