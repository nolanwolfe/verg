import SwiftUI

/// Main content view with tab navigation
struct ContentView: View {
    @EnvironmentObject private var storageService: StorageService
    @EnvironmentObject private var purchaseService: PurchaseService

    @State private var selectedTab: Tab = .write
    @State private var showOnboarding: Bool = true
    @State private var onboardingRunID: Int = 0
    @State private var showStartTimerNotice: Bool = false
    @State private var showTimerFromNotice: Bool = false

    enum Tab: String {
        case write
        case journal
        case verg
        case library
        case settings
    }

    var body: some View {
        ZStack {
            // Main app is always the base layer
            mainTabView

            // Onboarding overlay (first launch, or replayed from
            // Settings → Guide)
            if showOnboarding && !storageService.settings.hasSeenOnboarding {
                OnboardingView(onComplete: {
                    // Defer state changes to avoid "Publishing changes from within view updates"
                    DispatchQueue.main.async {
                        showOnboarding = false
                        handleOnboardingComplete()
                    }
                })
                .transition(.opacity)
                .id(onboardingRunID)
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
        // Settings → Guide: replay the onboarding immediately. Clears the
        // flag (so future launches also behave) and re-presents the overlay
        // in-place by bumping the run ID.
        .onReceive(NotificationCenter.default.publisher(for: .onboardingReplayRequested).receive(on: DispatchQueue.main)) { _ in
            storageService.replayOnboarding()
            onboardingRunID += 1
            showOnboarding = true
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
            // Re-evaluate the candle gap now that real entitlement data has
            // loaded — CandleService's own init ran with best-effort/cached
            // status, which may have been wrong for a subscriber on a cold
            // launch before this async check completes.
            await MainActor.run {
                CandleService.shared.refreshDaysLit()
            }
        }
    }

    // MARK: - Main Tab View

    /// The tab bar fades out as the user scrolls down and slides back in
    /// on scroll-up — content gets the full screen while reading, chrome
    /// returns the moment you head back up. The timer (Write) and candle
    /// (Verg) screens never hide it: they have no scroll and the bar is
    /// part of those rituals.
    private var mainTabView: some View {
        currentTabContent
            .environment(\.tabBarVisibility, $tabBarVisibility)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(selectedTab: $selectedTab)
                    .opacity(tabBarOpacity)
                    .offset(y: tabBarHidden ? 80 : 0)
                    .animation(Theme.Animation.standard, value: tabBarHidden)
                    .allowsHitTesting(!tabBarHidden)
            }
    }

    private var tabBarHidden: Bool {
        tabBarVisibility == .hidden
    }

    private var tabBarOpacity: Double {
        tabBarHidden ? 0 : 1
    }

    @State private var tabBarVisibility: TabBarVisibility = .visible

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
        case .library:
            LibraryView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    /// Fired by Settings → Guide to replay the onboarding sequence.
    static let onboardingReplayRequested = Notification.Name("onboardingReplayRequested")
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(StorageService.shared)
        .environmentObject(PurchaseService.shared)
}
