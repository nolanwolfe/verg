import Foundation
import StoreKit
import RevenueCat

final class PurchaseService: ObservableObject {
    static let shared = PurchaseService()

    // MARK: - Constants
    static let entitlementID = "premium"

    // MARK: - Published Properties
    @MainActor @Published private(set) var isSubscribed: Bool = false

    /// Manually set subscription status (used by RevenueCat PaywallView callbacks)
    @MainActor
    func setSubscribed(_ value: Bool) {
        isSubscribed = value
        print("[PurchaseService] setSubscribed(\(value))")
    }
    @MainActor @Published private(set) var isLoading: Bool = false
    @MainActor @Published private(set) var weeklyPrice: String = "$3.99"
    @MainActor @Published private(set) var yearlyPrice: String = "$99.99"
    @MainActor @Published private(set) var weeklyIntroOffer: String? = "3 days free"
    @MainActor @Published private(set) var yearlyIntroOffer: String? = "3 days free"
    @MainActor @Published var errorMessage: String?

    // MARK: - Product IDs
    private let weeklyID = "verg_weekly"
    private let yearlyID = "verg_yearly"

    // RevenueCat API key - empty means use StoreKit testing
    private let revenueCatAPIKey = "appl_wQqrrrHwpiBHrHJDqnuBKYOfysb"

    // MARK: - Private Properties
    private var products: [Product] = []
    private var updateListenerTask: Task<Void, Error>?
    private var currentOffering: Offering?

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
        if !revenueCatAPIKey.isEmpty {
            // Configure RevenueCat for production
            Purchases.logLevel = .debug
            print("[RC] Configuring RevenueCat with API key: \(revenueCatAPIKey.prefix(6))…")
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

    @MainActor
    func fetchOfferingsFromRevenueCat() async {
        do {
            print("[RC] Fetching offerings…")
            let offerings = try await Purchases.shared.offerings()
            self.currentOffering = offerings.current
            if let current = offerings.current {
                // Map weekly and yearly packages by identifier or product id
                if let weeklyPkg = current.availablePackages.first(where: { $0.identifier.lowercased().contains("week") || $0.storeProduct.productIdentifier == weeklyID }) {
                    if let formatted = weeklyPkg.storeProduct.priceFormatter?.string(from: weeklyPkg.storeProduct.price as NSDecimalNumber) {
                        weeklyPrice = formatted
                    } else {
                        weeklyPrice = "$\(weeklyPkg.storeProduct.price)"
                    }
                    if let intro = weeklyPkg.storeProduct.introductoryDiscount {
                        weeklyIntroOffer = intro.localizedSubscriptionPeriod
                    }
                }
                if let yearlyPkg = current.availablePackages.first(where: { $0.identifier.lowercased().contains("year") || $0.storeProduct.productIdentifier == yearlyID }) {
                    if let formatted = yearlyPkg.storeProduct.priceFormatter?.string(from: yearlyPkg.storeProduct.price as NSDecimalNumber) {
                        yearlyPrice = formatted
                    } else {
                        yearlyPrice = "$\(yearlyPkg.storeProduct.price)"
                    }
                    if let intro = yearlyPkg.storeProduct.introductoryDiscount {
                        yearlyIntroOffer = intro.localizedSubscriptionPeriod
                    }
                }
            } else {
                print("[RC][WARN] No current offering configured.")
            }
        } catch {
            print("[RC][ERROR] Failed to fetch offerings: \(error)")
            self.errorMessage = "RevenueCat offerings error: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch Products

    @MainActor
    func fetchProducts() async {
        if !revenueCatAPIKey.isEmpty && !isUsingStoreKitTesting {
            await fetchOfferingsFromRevenueCat()
        }

        // Always fetch StoreKit products so the native paywall has products available
        do {
            products = try await Product.products(for: [weeklyID, yearlyID])

            for product in products {
                if product.id == weeklyID {
                    weeklyPrice = product.displayPrice
                    weeklyIntroOffer = product.introOfferDescription
                } else if product.id == yearlyID {
                    yearlyPrice = product.displayPrice
                    yearlyIntroOffer = product.introOfferDescription
                }
            }
        } catch {
            print("Failed to fetch StoreKit products: \(error)")
        }
    }

    // MARK: - Subscription Status

    @MainActor
    func checkSubscriptionStatus() async {
        if !isUsingStoreKitTesting {
            // RevenueCat check
            print("[RC] Checking subscription status…")
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                print("[RC] CustomerInfo received. Active entitlements: \(customerInfo.entitlements.active.keys)")
                isSubscribed = customerInfo.entitlements[Self.entitlementID]?.isActive == true
            } catch {
                print("[RC][ERROR] customerInfo() failed: \(error)")
                self.errorMessage = "RevenueCat error: \(error.localizedDescription)"
                isSubscribed = false
            }
        } else {
            // StoreKit 2 check
            var hasSubscription = false
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if transaction.productID == weeklyID || transaction.productID == yearlyID {
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
    func purchaseWeekly() async -> Bool {
        guard let product = products.first(where: { $0.id == weeklyID }) else {
            if products.isEmpty {
                await fetchProducts()
            }
            guard let product = products.first(where: { $0.id == weeklyID }) else {
                errorMessage = "Product not found"
                return false
            }
            return await purchase(product)
        }
        return await purchase(product)
    }

    @MainActor
    func purchaseYearly() async -> Bool {
        guard let product = products.first(where: { $0.id == yearlyID }) else {
            if products.isEmpty {
                await fetchProducts()
            }
            guard let product = products.first(where: { $0.id == yearlyID }) else {
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
                    print("[Purchase] Success! isSubscribed = true")
                    // Sync with RevenueCat in production
                    if !isUsingStoreKitTesting {
                        try? await Purchases.shared.syncPurchases()
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
            print("Purchase error: \(error)")
            return false
        }
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
                print("[RC] Restore completed. Active entitlements: \(customerInfo.entitlements.active.keys)")
                isSubscribed = customerInfo.entitlements[Self.entitlementID]?.isActive == true
            } else {
                try await AppStore.sync()
                // Check for active subscriptions
                for await result in Transaction.currentEntitlements {
                    if case .verified(let transaction) = result {
                        if transaction.productID == weeklyID || transaction.productID == yearlyID {
                            if transaction.revocationDate == nil {
                                isSubscribed = true
                                print("[Restore] Found active subscription: \(transaction.productID)")
                                break
                            }
                        }
                    }
                }
            }
            print("[Restore] isSubscribed = \(isSubscribed)")
            return isSubscribed
        } catch {
            errorMessage = error.localizedDescription
            print("Restore error: \(error)")
            return false
        }
    }

    // MARK: - Helper Properties

    var weeklyProduct: Product? {
        products.first { $0.id == weeklyID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == yearlyID }
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

