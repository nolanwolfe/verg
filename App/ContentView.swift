import SwiftUI

/// Main content view with tab navigation
struct ContentView: View {
    @EnvironmentObject private var storageService: StorageService
    @EnvironmentObject private var purchaseService: PurchaseService

    @State private var selectedTab: Tab = .home
    @State private var showOnboarding: Bool = true
    @State private var showPaywallAfterOnboarding: Bool = false

    enum Tab: String {
        case home
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
                    showOnboarding = false
                    showPaywallAfterOnboarding = true
                })
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showPaywallAfterOnboarding) {
            PaywallView(onSubscribed: {
                showPaywallAfterOnboarding = false
            })
        }
        .onAppear {
            checkSubscriptionStatus()
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
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(Tab.stats)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(Theme.Colors.accent)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(StorageService.shared)
        .environmentObject(PurchaseService.shared)
}
