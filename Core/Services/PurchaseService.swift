import Foundation
import CryptoKit
import StoreKit
import RevenueCat

final class PurchaseService: ObservableObject {
    static let shared = PurchaseService()

    // MARK: - Constants
    static let entitlementID = "premium"

    // Friends & Family / UGC partner access codes.
    //
    // Digests, not codes. The codes themselves were plain strings here
    // until 2.2, in a public repository — anyone browsing GitHub could read
    // them and grant themselves permanent access, and they remain readable
    // in this file's history, which is why the codes were rotated rather
    // than merely moved. The old ones no longer work.
    //
    // What is stored is SHA-256 of `accessCodeSalt + code`. That keeps the
    // repository safe to publish and keeps the codes out of `strings` on
    // the shipped binary. It is obfuscation, not cryptography: the digests
    // ship in the app, so someone determined enough to extract them could
    // brute-force short codes offline. The random suffix on each code is
    // what makes that expensive. The real fix is server-side validation —
    // RevenueCat's own promotional entitlements or App Store offer codes —
    // and this should move there before the codes are shared widely.
    //
    // To add one: hash `accessCodeSalt + CODE` and paste the digest here.
    // Keep the plaintext somewhere that is not this repository.
    private static let accessCodeSalt = "verg.access.v2"
    static let validAccessCodeDigests: Set<String> = [
        "66c04fda514fa97102d25a13246b16a086dc92337c038a6dbd8fa04277b68aef",  // friends & family
        "430af88ef11d12929c3ea0500d432fef34ceaed2558dde2d11581e16da3d8264",  // UGC / marketing partners
        "1412ec2a2095625422924112a03018cb6a87ccf30efaef71864dbd6e675dfb71"   // launch campaign
    ]

    /// Hex SHA-256 of the salted code, matching how the digests above were
    /// generated.
    private static func accessCodeDigest(_ normalized: String) -> String {
        SHA256.hash(data: Data((accessCodeSalt + normalized).utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
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
                if let intro = storeProduct.introductoryDiscount {
                    // Bare period, like the StoreKit path — the paywall adds
                    // the words.
                    yearlyIntroOffer = intro.freeTrialPeriod
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
        guard Self.validAccessCodeDigests.contains(Self.accessCodeDigest(normalized)) else {
            return false
        }
        isFriendsAndFamily = true
        UserDefaults.standard.set(true, forKey: friendsAndFamilyKey)
        #if DEBUG
        // The code itself is deliberately not logged — a console line is
        // one screen-share away from being public again.
        print("[PurchaseService] Friends & Family access granted")
        #endif
        return true
    }

    #if DEBUG
    /// Clear granted access, for UI tests.
    ///
    /// Friends & Family is persisted, so anything that redeems a code —
    /// including a unit test, which runs hosted by the app and writes to the
    /// app's own defaults — grants premium to the simulator permanently. The
    /// gating tests then fail reporting that locked pages open, which reads
    /// as a paywall bypass and is not one. That happened; this is so it
    /// cannot happen twice.
    @MainActor
    func resetGrantedAccessForUITesting() {
        isFriendsAndFamily = false
        UserDefaults.standard.removeObject(forKey: friendsAndFamilyKey)
    }

    /// Grant access, for the App Store screenshot pass only.
    ///
    /// The store shots should show the app as someone who has paid for it
    /// sees it — a full wall of pages. Without this the journal renders
    /// mostly padlocks, which is the gate working correctly and a poor thing
    /// to advertise. DEBUG only, reached only by an explicit launch
    /// argument, and it grants nothing a real build could.
    @MainActor
    func grantAccessForScreenshots() {
        isFriendsAndFamily = true
    }
    #endif

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
    /// The free-trial length alone — "3 days" — matching `Product.freeTrialPeriod`.
    ///
    /// `localizedSubscriptionPeriod` below appends "free", so the two sources
    /// disagreed and the paywall, which composes its own sentence around the
    /// value, rendered "3 days free free trial". Fixing only the StoreKit
    /// side left this one, and RevenueCat is the path a real device takes.
    var freeTrialPeriod: String? {
        guard paymentMode == .freeTrial else { return nil }
        let value = subscriptionPeriod.value
        switch subscriptionPeriod.unit {
        case .day:   return value == 1 ? "1 day" : "\(value) days"
        case .week:  return value == 1 ? "1 week" : "\(value) weeks"
        case .month: return value == 1 ? "1 month" : "\(value) months"
        case .year:  return value == 1 ? "1 year" : "\(value) years"
        @unknown default: return nil
        }
    }

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

