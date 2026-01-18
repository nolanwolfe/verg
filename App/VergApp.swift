import SwiftUI
import UIKit

/// Main app entry point
@main
struct VergApp: App {
    // MARK: - Services
    @StateObject private var storageService = StorageService.shared
    @StateObject private var purchaseService = PurchaseService.shared

    // MARK: - Initialization
    init() {
        configureAppearance()
        // Configure RevenueCat here when ready:
        // Purchases.configure(withAPIKey: "your_api_key")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storageService)
                .environmentObject(purchaseService)
                .preferredColorScheme(.dark)
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
