import Foundation

/// Single source of truth for RevenueCat/StoreKit product identifiers.
/// Must match the product IDs configured in App Store Connect exactly
/// (case-sensitive).
///
/// A weekly subscription SKU and a "Pro Access" SKU are referenced in the
/// business brief as things to retire/resolve, but neither appears
/// anywhere in this codebase or the local StoreKit test config — they're
/// App Store Connect/RevenueCat-dashboard-only artifacts this file has
/// never known about. See the manual-actions list in RELEASE_NOTES_2.2.md.
enum ProductIdentifiers {
    static let monthly = "Verg_Monthly"
    static let yearly = "Verg_Yearly"
}
