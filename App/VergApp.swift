import SwiftUI
import UIKit

/// Main app entry point
@main
struct VergApp: App {
    // MARK: - Services
    @StateObject private var storageService = StorageService.shared
    @StateObject private var purchaseService = PurchaseService.shared
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Initialization
    init() {
        configurePurchases()
        configureAppearance()
    }

    // MARK: - Purchase Configuration
    private func configurePurchases() {
        // PurchaseService handles both StoreKit testing and RevenueCat
        // Set revenueCatAPIKey in PurchaseService.swift when ready for production
        PurchaseService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storageService)
                .environmentObject(purchaseService)
                // Appearance is resolved in ContentView, which knows which
                // tab is on screen — the candle tabs are dark whatever the
                // setting says, and that has to reach the window so the
                // status bar and tab bar come with them.
        }
        // Screen brightness is the app's for as long as the app is in front,
        // and the user's again the moment it isn't. This is the *only* place
        // it is handed back — screens no longer restore it on disappear, so
        // moving between tabs leaves it alone.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                BrightnessService.shared.reapplyAfterForeground()
            case .background:
                // `.background` only. `.inactive` also fires for a pulled-down
                // Control Center, a notification banner, or a glance at the
                // app switcher — handing brightness back on any of those made
                // the screen jump while the app was still on screen, which is
                // exactly the reset this service exists to prevent.
                BrightnessService.shared.relinquish()
            case .inactive:
                // Momentary — the app is still on screen. Leave brightness be.
                break
            @unknown default:
                break
            }
        }
    }

    // MARK: - Appearance Configuration
    private func configureAppearance() {
        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Theme.Colors.background)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(Theme.Colors.background)
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Theme.Colors.primaryText)
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Theme.Colors.primaryText)
        ]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance

        // Tint color
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Theme.Colors.accent)
    }
}
