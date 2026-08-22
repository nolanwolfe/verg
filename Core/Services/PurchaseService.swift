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
    @MainActor @Published private(set) var monthlyPrice: String = "$4.99"
    @MainActor @Published private(set) var yearlyPrice: String = "$60.00"
    @MainActor @Published private(set) var monthlyIntroOffer: String? = "30 days free"
    @MainActor @Published private(set) var yearlyIntroOffer: String? = "30 days free"
    @MainActor @Published var errorMessage: String?

    // MARK: - Product IDs
    private let monthlyID = "Verg_Monthly"
    private let yearlyID = "Verg_Yearly"

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

    @MainActor
    func fetchOfferingsFromRevenueCat() async {
        do {
            #if DEBUG
            print("[RC] Fetching offerings…")
            #endif
            let offerings = try await Purchases.shared.offerings()
            self.currentOffering = offerings["premium"] ?? offerings.current
            if let current = self.currentOffering {
                // Map monthly and yearly packages by identifier or product id
                if let monthlyPkg = current.availablePackages.first(where: { $0.identifier.lowercased().contains("month") || $0.storeProduct.productIdentifier == monthlyID }) {
                    if let formatted = monthlyPkg.storeProduct.priceFormatter?.string(from: monthlyPkg.storeProduct.price as NSDecimalNumber) {
                        monthlyPrice = formatted
                    } else {
                        monthlyPrice = "$\(monthlyPkg.storeProduct.price)"
                    }
                    if let intro = monthlyPkg.storeProduct.introductoryDiscount {
                        monthlyIntroOffer = intro.localizedSubscriptionPeriod
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
                #if DEBUG
                print("[RC][WARN] No current offering configured.")
                #endif
            }
        } catch {
            #if DEBUG
            print("[RC][ERROR] Failed to fetch offerings: \(error)")
            #endif
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
            products = try await Product.products(for: [monthlyID, yearlyID])

            for product in products {
                if product.id == monthlyID {
                    monthlyPrice = product.displayPrice
                    monthlyIntroOffer = product.introOfferDescription
                } else if product.id == yearlyID {
                    yearlyPrice = product.displayPrice
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
                    if transaction.productID == monthlyID || transaction.productID == yearlyID {
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
        guard let product = products.first(where: { $0.id == monthlyID }) else {
            if products.isEmpty {
                await fetchProducts()
            }
            guard let product = products.first(where: { $0.id == monthlyID }) else {
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
                        if transaction.productID == monthlyID || transaction.productID == yearlyID {
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
        products.first { $0.id == monthlyID }
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

