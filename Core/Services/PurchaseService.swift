import Foundation
import StoreKit
import RevenueCat

final class PurchaseService: ObservableObject {
    static let shared = PurchaseService()

    // MARK: - Constants
    static let entitlementID = "premium"

    // Friends & Family / UGC partner access codes
    // Share these codes with friends, family, and UGC marketing partners
    // Add new codes here as needed; existing codes never expire
    static let validAccessCodes: Set<String> = [
        "VERGFAM",      // friends & family (legacy)
        "VERGVIP",      // UGC / marketing partners
        "ONTHEVERG"     // Verg 2.0 launch campaign
    ]
    private let friendsAndFamilyKey = "verg.isFriendsAndFamily"

    // MARK: - Published Properties
    @MainActor @Published private(set) var isSubscribed: Bool = false
    @MainActor @Published private(set) var isFriendsAndFamily: Bool = false

    /// Manually set subscription status (used by RevenueCat PaywallView callbacks)
    @MainActor
    func setSubscribed(_ value: Bool) {
        isSubscribed = value
        #if DEBUG
        print("[PurchaseService] setSubscribed(\(value))")
        #endif
    }
    @MainActor @Published private(set) var isLoading: Bool = false
    // No hardcoded fallback numbers — empty until real data loads, so the
    // paywall never flashes a price or trial length that isn't real.
    @MainActor @Published private(set) var monthlyPrice: String = ""
    @MainActor @Published private(set) var yearlyPrice: String = ""
    /// The per-year price divided by 12, formatted with the same currency
    /// formatter — for the "$X/mo" equivalence shown next to Yearly.
    @MainActor @Published private(set) var yearlyMonthlyEquivalentPrice: String = ""
    @MainActor @Published private(set) var monthlyIntroOffer: String?
    @MainActor @Published private(set) var yearlyIntroOffer: String?
    /// Whether *this* subscriber is eligible for Yearly's introductory
    /// offer — distinct from whether the product has one configured at
    /// all. A previously-subscribed (lapsed) user typically isn't eligible
    /// even though the product still has an intro offer attached.
    @MainActor @Published private(set) var yearlyIntroEligible: Bool = true
    @MainActor @Published var errorMessage: String?

    // RevenueCat API key - empty means use StoreKit testing
    private let revenueCatAPIKey = "appl_wQqrrrHwpiBHrHJDqnuBKYOfysb"

    // MARK: - Private Properties
    private var products: [Product] = []
    private var updateListenerTask: Task<Void, Error>?
    @MainActor @Published private(set) var currentOffering: Offering?

    var isUsingStoreKitTesting: Bool {
        revenueCatAPIKey.isEmpty
    }

    // MARK: - Initialization
    private init() {}

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Configuration

    @MainActor
    func configure() {
        // Load persisted friends & family status
        isFriendsAndFamily = UserDefaults.standard.bool(forKey: friendsAndFamilyKey)

        if !revenueCatAPIKey.isEmpty {
            // Configure RevenueCat for production
            // Verbose logging exposes customer/receipt details in the device
            // console — keep it out of release builds
            #if DEBUG
            Purchases.logLevel = .debug
            print("[RC] Configuring RevenueCat with API key: \(revenueCatAPIKey.prefix(6))…")
            #else
            Purchases.logLevel = .error
            #endif
            Purchases.configure(withAPIKey: revenueCatAPIKey)
            Task {
                await fetchOfferingsFromRevenueCat()
            }
        }

        if isUsingStoreKitTesting {
            // Listen for StoreKit transactions (DEBUG or when no RC key)
            updateListenerTask = listenForTransactions()
        }

        Task {
            await fetchProducts()
            await checkSubscriptionStatus()
        }
    }

    // MARK: - Transaction Listener (StoreKit 2)

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self?.checkSubscriptionStatus()
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Fetch Offerings from RevenueCat
    // RevenueCat's offerings are the source of truth for everything the
    // paywall displays (price, trial copy, eligibility) — never hardcoded.
    // fetchProducts() below only uses raw StoreKit for the Product handle
    // the actual purchase transaction needs, not for display text.

    @MainActor
    func fetchOfferingsFromRevenueCat() async {
        do {
            #if DEBUG
            print("[RC] Fetching offerings…")
            #endif
            let offerings = try await Purchases.shared.offerings()
            self.currentOffering = offerings["premium"] ?? offerings.current
            guard let current = self.currentOffering else {
                #if DEBUG
                print("[RC][WARN] No current offering configured.")
                #endif
                return
            }

            // Map monthly and yearly packages by identifier or product id
            if let monthlyPkg = current.availablePackages.first(where: { $0.identifier.lowercased().contains("month") || $0.storeProduct.productIdentifier == ProductIdentifiers.monthly }) {
                monthlyPrice = formattedPrice(monthlyPkg.storeProduct.price, using: monthlyPkg.storeProduct.priceFormatter)
                if let intro = monthlyPkg.storeProduct.introductoryDiscount {
                    monthlyIntroOffer = intro.localizedSubscriptionPeriod
                }
            }
            if let yearlyPkg = current.availablePackages.first(where: { $0.identifier.lowercased().contains("year") || $0.storeProduct.productIdentifier == ProductIdentifiers.yearly }) {
                let storeProduct = yearlyPkg.storeProduct
                yearlyPrice = formattedPrice(storeProduct.price, using: storeProduct.priceFormatter)
                yearlyMonthlyEquivalentPrice = formattedPrice(storeProduct.price / 12, using: storeProduct.priceFormatter)
                if let intro = storeProduct.introductoryDiscount {
                    yearlyIntroOffer = intro.localizedSubscriptionPeriod
                }
                await refreshYearlyIntroEligibility()
            }
        } catch {
            #if DEBUG
            print("[RC][ERROR] Failed to fetch offerings: \(error)")
            #endif
            self.errorMessage = "RevenueCat offerings error: \(error.localizedDescription)"
        }
    }

    private func formattedPrice(_ price: Decimal, using formatter: NumberFormatter?) -> String {
        if let formatted = formatter?.string(from: price as NSDecimalNumber) {
            return formatted
        }
        return "$\(price)"
    }

    /// Whether *this* subscriber (not just the product) is eligible for
    /// Yearly's introductory offer — a lapsed subscriber who already used
    /// the trial is not, even though the product still has one configured.
    @MainActor
    private func refreshYearlyIntroEligibility() async {
        let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: [ProductIdentifiers.yearly]
        )
        if let status = eligibility[ProductIdentifiers.yearly]?.status {
            yearlyIntroEligible = (status == .eligible)
        }
    }

    // MARK: - Fetch Products

    @MainActor
    func fetchProducts() async {
        if !revenueCatAPIKey.isEmpty && !isUsingStoreKitTesting {
            await fetchOfferingsFromRevenueCat()
        }

        // Fetch StoreKit products so purchaseMonthly()/purchaseYearly() have
        // a Product to call .purchase() on — this does NOT drive display
        // text when RevenueCat is configured; only the StoreKit-testing
        // fallback below (no RC key) uses it for pricing/offer copy too.
        do {
            products = try await Product.products(for: [ProductIdentifiers.monthly, ProductIdentifiers.yearly])

            guard isUsingStoreKitTesting else { return }
            for product in products {
                if product.id == ProductIdentifiers.monthly {
                    monthlyPrice = product.displayPrice
                    monthlyIntroOffer = product.introOfferDescription
                } else if product.id == ProductIdentifiers.yearly {
                    yearlyPrice = product.displayPrice
                    if let subscription = product.subscription {
                        yearlyMonthlyEquivalentPrice = formattedPrice(product.price / 12, using: nil)
                        yearlyIntroEligible = await subscription.isEligibleForIntroOffer
                    }
                    yearlyIntroOffer = product.introOfferDescription
                }
            }
        } catch {
            #if DEBUG
            print("Failed to fetch StoreKit products: \(error)")
            #endif
        }
    }

    // MARK: - Subscription Status

    @MainActor
    func checkSubscriptionStatus() async {
        if !isUsingStoreKitTesting {
            // RevenueCat check
            #if DEBUG
            print("[RC] Checking subscription status…")
            #endif
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                #if DEBUG
                print("[RC] CustomerInfo received. Active entitlements: \(customerInfo.entitlements.active.keys)")
                #endif
                isSubscribed = customerInfo.entitlements[Self.entitlementID]?.isActive == true
            } catch {
                #if DEBUG
                print("[RC][ERROR] customerInfo() failed: \(error)")
                #endif
                self.errorMessage = "RevenueCat error: \(error.localizedDescription)"
                isSubscribed = false
            }
        } else {
            // StoreKit 2 check
            var hasSubscription = false
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if transaction.productID == ProductIdentifiers.monthly || transaction.productID == ProductIdentifiers.yearly {
                        if transaction.revocationDate == nil {
                            hasSubscription = true
                            break
                        }
                    }
                }
            }
            isSubscribed = hasSubscription
        }
    }

    // MARK: - Purchase Methods

    @MainActor
    func purchaseMonthly() async -> Bool {
        guard let product = products.first(where: { $0.id == ProductIdentifiers.monthly }) else {
            if products.isEmpty {
                await fetchProducts()
            }
            guard let product = products.first(where: { $0.id == ProductIdentifiers.monthly }) else {
                errorMessage = "Product not found"
                return false
            }
            return await purchase(product)
        }
        return await purchase(product)
    }

    @MainActor
    func purchaseYearly() async -> Bool {
        guard let product = products.first(where: { $0.id == ProductIdentifiers.yearly }) else {
            if products.isEmpty {
                await fetchProducts()
            }
            guard let product = products.first(where: { $0.id == ProductIdentifiers.yearly }) else {
                errorMessage = "Product not found"
                return false
            }
            return await purchase(product)
        }
        return await purchase(product)
    }

    @MainActor
    private func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    // Set subscribed immediately after successful purchase
                    isSubscribed = true
                    #if DEBUG
                    print("[Purchase] Success! isSubscribed = true")
                    #endif
                    // Sync with RevenueCat in production
                    if !isUsingStoreKitTesting {
                        _ = try? await Purchases.shared.syncPurchases()
                    }
                    return true
                case .unverified:
                    errorMessage = "Purchase verification failed"
                    return false
                }
            case .pending:
                errorMessage = "Purchase is pending approval"
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("Purchase error: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Friends & Family / Access Code Redemption

    /// Redeem an access code to grant friends-and-family unlimited access.
    /// Returns true if the code is valid.
    @MainActor
    @discardableResult
    func redeemAccessCode(_ code: String) -> Bool {
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.validAccessCodes.contains(normalized) else {
            return false
        }
        isFriendsAndFamily = true
        UserDefaults.standard.set(true, forKey: friendsAndFamilyKey)
        #if DEBUG
        print("[PurchaseService] Friends & Family access granted via code: \(normalized)")
        #endif
        return true
    }

    // MARK: - Restore Purchases

    @MainActor
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if !isUsingStoreKitTesting {
                let customerInfo = try await Purchases.shared.restorePurchases()
                #if DEBUG
                print("[RC] Restore completed. Active entitlements: \(customerInfo.entitlements.active.keys)")
                #endif
                isSubscribed = customerInfo.entitlements[Self.entitlementID]?.isActive == true
            } else {
                try await AppStore.sync()
                // Check for active subscriptions
                for await result in Transaction.currentEntitlements {
                    if case .verified(let transaction) = result {
                        if transaction.productID == ProductIdentifiers.monthly || transaction.productID == ProductIdentifiers.yearly {
                            if transaction.revocationDate == nil {
                                isSubscribed = true
                                #if DEBUG
                                print("[Restore] Found active subscription: \(transaction.productID)")
                                #endif
                                break
                            }
                        }
                    }
                }
            }
            #if DEBUG
            print("[Restore] isSubscribed = \(isSubscribed)")
            #endif
            return isSubscribed
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("Restore error: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Helper Properties

    var monthlyProduct: Product? {
        products.first { $0.id == ProductIdentifiers.monthly }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == ProductIdentifiers.yearly }
    }
}

// MARK: - Product Extensions
extension Product {
    /// Introductory offer description if available
    var introOfferDescription: String? {
        guard let intro = subscription?.introductoryOffer else { return nil }

        let period = intro.period
        let periodName: String

        switch period.unit {
        case .day:
            periodName = period.value == 1 ? "1 day" : "\(period.value) days"
        case .week:
            periodName = period.value == 1 ? "1 week" : "\(period.value) weeks"
        case .month:
            periodName = period.value == 1 ? "1 month" : "\(period.value) months"
        case .year:
            periodName = period.value == 1 ? "1 year" : "\(period.value) years"
        @unknown default:
            periodName = "\(period.value) periods"
        }

        switch intro.paymentMode {
        case .freeTrial:
            return "\(periodName) free"
        case .payAsYouGo:
            return "\(intro.displayPrice) for \(periodName)"
        case .payUpFront:
            return "\(intro.displayPrice) for \(periodName)"
        default:
            return nil
        }
    }
}

// MARK: - StoreProductDiscount Extensions
extension StoreProductDiscount {
    var localizedSubscriptionPeriod: String {
        let unit: String
        switch subscriptionPeriod.unit {
        case .day: unit = subscriptionPeriod.value == 1 ? "1 day" : "\(subscriptionPeriod.value) days"
        case .week: unit = subscriptionPeriod.value == 1 ? "1 week" : "\(subscriptionPeriod.value) weeks"
        case .month: unit = subscriptionPeriod.value == 1 ? "1 month" : "\(subscriptionPeriod.value) months"
        case .year: unit = subscriptionPeriod.value == 1 ? "1 year" : "\(subscriptionPeriod.value) years"
        @unknown default: unit = "\(subscriptionPeriod.value) periods"
        }
        switch paymentMode {
        case .freeTrial:
            return "\(unit) free"
        case .payAsYouGo, .payUpFront:
            // We can't build a localized price string without a locale here; keep period only
            return unit
        @unknown default:
            return unit
        }
    }
}

// MARK: - Purchase Errors
enum PurchaseError: LocalizedError {
    case productNotFound
    case verificationFailed
    case pending
    case networkError

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .verificationFailed:
            return "Purchase verification failed"
        case .pending:
            return "Purchase is pending"
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}

