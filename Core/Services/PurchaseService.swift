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
            // Deliberately no offerings fetch here: `fetchProducts()` below
            // already calls it whenever there is an API key. Doing both meant
            // two concurrent passes writing the same published price
            // properties on every launch, for one set of prices.
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
                yearlyMonthlyEquivalentPrice = formattedMonthlyEquivalent(storeProduct.price, using: storeProduct.priceFormatter)
                // Free trials only. A paid introductory price is still an
                // "introductory discount", and calling one a free trial on
                // the paywall would be a straightforward false claim.
                if let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
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

    /// The "/mo" figure on the Yearly row. Floors to the cent rather than
    /// rounding: $59.99 ÷ 12 is $4.9992, and rounding it to $5.00 both
    /// overstates the price and loses the point of the number. Flooring
    /// can never claim the plan is cheaper than it is.
    private func formattedMonthlyEquivalent(_ yearly: Decimal, using formatter: NumberFormatter?) -> String {
        var perMonth = yearly / 12
        var floored = Decimal()
        NSDecimalRound(&floored, &perMonth, 2, .down)
        return formattedPrice(floored, using: formatter)
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

            // Fallback: RevenueCat's offering metadata can arrive without the
            // introductory offer even when App Store Connect has one attached
            // to the product — a misconfigured offering then hides a trial the
            // subscriber is genuinely entitled to. StoreKit is asked directly
            // rather than assuming. This reads the real product; it never
            // invents an offer, so a product with no trial still shows none.
            if !isUsingStoreKitTesting, yearlyIntroOffer == nil,
               let yearly = products.first(where: { $0.id == ProductIdentifiers.yearly }) {
                yearlyIntroOffer = yearly.freeTrialPeriod
                if yearlyIntroOffer != nil, let subscription = yearly.subscription {
                    yearlyIntroEligible = await subscription.isEligibleForIntroOffer
                }
            }

            #if DEBUG
            logTrialDiagnosis()
            #endif

            guard isUsingStoreKitTesting else { return }
            for product in products {
                if product.id == ProductIdentifiers.monthly {
                    monthlyPrice = product.displayPrice
                    monthlyIntroOffer = product.introOfferDescription
                } else if product.id == ProductIdentifiers.yearly {
                    yearlyPrice = product.displayPrice
                    if let subscription = product.subscription {
                        yearlyMonthlyEquivalentPrice = formattedMonthlyEquivalent(product.price, using: nil)
                        yearlyIntroEligible = await subscription.isEligibleForIntroOffer
                    }
                    yearlyIntroOffer = product.freeTrialPeriod
                }
            }
        } catch {
            #if DEBUG
            print("Failed to fetch StoreKit products: \(error)")
            #endif
        }
    }

    #if DEBUG
    /// Why the trial badge is or is not showing, in enough detail to tell a
    /// propagation delay apart from a misconfiguration.
    ///
    /// Read this from the Xcode console on a real device with a sandbox
    /// tester signed in. A simulator cannot settle the question: it will
    /// resolve the product and its price, but introductory-offer metadata and
    /// `isEligibleForIntroOffer` both depend on a signed-in App Store account.
    @MainActor
    private func logTrialDiagnosis() {
        let product = products.first { $0.id == ProductIdentifiers.yearly }

        var lines = ["[Trial] ── why the trial badge is/isn't showing ──"]
        lines.append("  shown to user   : \(yearlyIntroOffer != nil && yearlyIntroEligible)")
        lines.append("  product found   : \(product != nil) (\(ProductIdentifiers.yearly))")
        lines.append("  product price   : \(product?.displayPrice ?? "—")")

        if let intro = product?.subscription?.introductoryOffer {
            lines.append("  StoreKit offer  : YES — \(intro.paymentMode) "
                         + "\(intro.period.value) \(intro.period.unit)")
        } else {
            lines.append("  StoreKit offer  : none on the product")
        }

        if let rcDiscount = currentOffering?
            .availablePackages
            .first(where: { $0.storeProduct.productIdentifier == ProductIdentifiers.yearly })?
            .storeProduct.introductoryDiscount {
            lines.append("  RevenueCat offer: YES — \(rcDiscount.paymentMode)")
        } else {
            lines.append("  RevenueCat offer: none (offering: "
                         + "\(currentOffering?.identifier ?? "not loaded"))")
        }

        lines.append("  eligible        : \(yearlyIntroEligible)")

        let verdict: String
        if product == nil {
            verdict = "product not resolving — check the ID and the paid-apps agreement"
        } else if product?.subscription?.introductoryOffer == nil {
            verdict = "no offer on the product. Either App Store Connect has not "
                + "propagated yet (often hours), the offer is not in an Approved "
                + "state, or this is a simulator with no sandbox account signed in."
        } else if !yearlyIntroEligible {
            verdict = "the offer exists but THIS account is not eligible — it has "
                + "already used the trial. Try a fresh sandbox tester."
        } else {
            verdict = "all clear — the badge should be showing"
        }
        lines.append("  verdict         : \(verdict)")

        print(lines.joined(separator: "\n"))
    }
    #endif

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
    /// The free-trial length alone — "3 days".
    ///
    /// Bare period, deliberately: RevenueCat's path already yields just the
    /// period while `introOfferDescription` yields "3 days free", and having
    /// two sources emit two phrasings produced "3 days free free trial" on
    /// whichever path the device happened to take. The paywall composes the
    /// sentence; both sources supply only the length.
    ///
    /// Nil for a paid introductory price — that is an introductory offer but
    /// not a free trial, and the paywall's wording would be false.
    var freeTrialPeriod: String? {
        guard let intro = subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return nil }
        let period = intro.period
        switch period.unit {
        case .day:   return period.value == 1 ? "1 day" : "\(period.value) days"
        case .week:  return period.value == 1 ? "1 week" : "\(period.value) weeks"
        case .month: return period.value == 1 ? "1 month" : "\(period.value) months"
        case .year:  return period.value == 1 ? "1 year" : "\(period.value) years"
        @unknown default: return nil
        }
    }

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

