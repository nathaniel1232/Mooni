import Foundation
import Combine
import RevenueCat

/// Result of a purchase attempt, rich enough for the UI to distinguish a
/// charged-but-not-yet-activated user from a hard failure or a cancel.
enum PurchaseOutcome {
    /// Entitlement is visible — the user is Pro right now.
    case active
    /// The StoreKit purchase succeeded but the entitlement is not yet visible
    /// (sandbox lag / receipt sync). The UI must NOT strand a charged user on
    /// the buy screen — show a "finalizing" state and keep observing isPro.
    case pendingActivation
    /// The user backed out of the StoreKit sheet.
    case cancelled
    /// The purchase threw. Associated value is a user-presentable message.
    case failed(String)
}

/// Result of a restore attempt so the UI can give explicit feedback.
enum RestoreOutcome {
    case restored
    case nothingToRestore
    case failed(String)
}

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    /// UserDefaults key for the last-known Pro state. Lets the UI render the
    /// correct (Pro) chrome on launch instead of flashing the free state for
    /// the moment before the async customerInfo fetch returns. Entitlement
    /// remains the source of truth — this cache is only a paint-time hint.
    private static let cachedIsProKey = "mooni.cachedIsPro"

    // MARK: - Published

    /// Sourced from RevenueCat at launch and seeded from a UserDefaults cache so
    /// the UI doesn't flash the free state before the async fetch returns.
    /// Entitlement status remains the source of truth and is re-fetched on app
    /// start; the cache is kept in sync via didSet.
    @Published var isPro: Bool = false {
        didSet {
            if oldValue != isPro {
                UserDefaults.standard.set(isPro, forKey: Self.cachedIsProKey)
            }
        }
    }
    @Published var currentOffering: Offering?
    @Published var discountOffering: Offering?
    @Published var isLoading: Bool = false
    @Published var isLoadingOfferings: Bool = true
    @Published var errorMessage: String?

    /// Entitlement identifier configured in RevenueCat dashboard. Must match
    /// exactly. We also accept any active entitlement as a fallback so a
    /// dashboard typo doesn't lock a paying user out.
    private static let entitlementID = "SleepOwl Pro"

    /// Identifier of the discounted offering configured in RevenueCat. Create
    /// an Offering named `discount` in the dashboard with a separate, lower-
    /// priced annual product (e.g. `sleepowl_annual_discount_4999`). The
    /// discount paywall charges THIS package — never half-prices the regular
    /// one, which would charge full price while showing a discount.
    private static let discountOfferingID = "discount"

    private init() {
        UserDefaults.standard.removeObject(forKey: "mooni.devForcePro")
        // Seed from the last-known cache so the UI paints the correct chrome
        // immediately. refreshCustomerInfo() (called from configure()) will
        // reconcile against the real entitlement a moment later.
        isPro = UserDefaults.standard.bool(forKey: Self.cachedIsProKey)
    }

    // MARK: - Configuration

    func configure() {
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: "appl_NHazhFbSVJwZapxrWPhcOVfrGma")
        Purchases.shared.delegate = MooniPurchasesDelegate.shared
        Task {
            // If we already have a persisted Supabase session from a prior
            // launch, re-attach RevenueCat to that user ID before fetching
            // entitlements. Without this, a reinstall on the same device
            // would briefly run as anonymous and miss the user's purchases
            // until they signed in again.
            if let uid = Supa.currentUserID {
                _ = try? await Purchases.shared.logIn(uid.uuidString)
            }
            await refreshAll()
        }
    }

    // MARK: - Data loading

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshCustomerInfo() }
            group.addTask { await self.loadOfferings() }
        }
    }

    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPro = Self.hasProEntitlement(in: info)
        } catch {
            // Silently fail — no internet or sandbox; treat as non-pro
        }
    }

    /// Treat the user as Pro if our named entitlement is active OR any
    /// entitlement is active (defensive: protects against an entitlement
    /// rename/typo in the RevenueCat dashboard locking out paying users).
    /// Non-private so the purchases delegate can reuse the exact same check
    /// rather than re-implementing it against the literal entitlement string.
    static func hasProEntitlement(in info: CustomerInfo) -> Bool {
        if info.entitlements.active[entitlementID] != nil { return true }
        return !info.entitlements.active.isEmpty
    }

    func loadOfferings() async {
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
            discountOffering = offerings.all[Self.discountOfferingID]
            #if DEBUG
            Self.printOfferingDiagnostics(offerings)
            #endif
        } catch {
            #if DEBUG
            print("⚠️ RevenueCat: failed to load offerings — \(error.localizedDescription)")
            #endif
        }
    }

    /// Prints a single-line readout in DEBUG so you can verify at a glance
    /// that the dashboard has the products you expect. If you don't see your
    /// `current` offering or your annual package here, the rest of the app
    /// will silently fall back to a fake-price state — fix the dashboard
    /// before debugging anything else.
    #if DEBUG
    private static func printOfferingDiagnostics(_ offerings: Offerings) {
        guard let current = offerings.current else {
            print("⚠️ RevenueCat: NO current offering. Set one as Current in the dashboard.")
            return
        }
        print("✅ RevenueCat current offering: \(current.identifier)")
        for pkg in current.availablePackages {
            let p = pkg.storeProduct
            let intro: String
            if let d = p.introductoryDiscount {
                intro = " (intro: \(d.subscriptionPeriod.value) \(d.subscriptionPeriod.unit) free)"
            } else {
                intro = ""
            }
            print("   • \(pkg.identifier) \(p.localizedPriceString)\(intro) — \(p.productIdentifier)")
        }
        if let disc = offerings.all[discountOfferingID] {
            print("✅ RevenueCat discount offering: \(disc.identifier)")
        } else {
            print("ℹ️ RevenueCat: no `discount` offering found — win-back paywall will show non-discount CTA.")
        }
    }
    #endif

    /// The annual package that should be charged on the win-back paywall.
    /// Returns the discount offering's annual if configured, otherwise nil so
    /// the UI can hide the false-discount framing rather than charging full
    /// price under a "50% off" banner.
    var discountAnnualPackage: Package? {
        discountOffering?.availablePackages.first { $0.packageType == .annual }
    }

    /// Original-price annual package, used to render a "Was X / Now Y" comparison
    /// honestly against the discount package's actual price.
    var regularAnnualPackage: Package? {
        currentOffering?.availablePackages.first { $0.packageType == .annual }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(package: Package) async -> PurchaseOutcome {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }

            // The customerInfo on the purchase result is the freshest source
            // of truth — use it directly rather than racing a second fetch.
            isPro = Self.hasProEntitlement(in: result.customerInfo)
            if isPro { return .active }

            // Entitlement not yet visible (sandbox lag, missing entitlement
            // attachment in App Store Connect, or first-time receipt sync).
            // Poll a few times with backoff, re-fetching customerInfo between
            // attempts, and break the moment the entitlement appears. The
            // delegate may also flip isPro from underneath us — honour that.
            let backoffsNanos: [UInt64] = [
                800_000_000,   // 0.8s
                1_500_000_000, // 1.5s
                2_500_000_000, // 2.5s
                4_000_000_000  // 4s
            ]
            for delay in backoffsNanos {
                try? await Task.sleep(nanoseconds: delay)
                if isPro { break }
                await refreshCustomerInfo()
                if isPro { break }
            }

            // Charged but not yet activated: never strand the user on the buy
            // screen — the UI shows a "finalizing" state and keeps watching isPro.
            return isPro ? .active : .pendingActivation
        } catch {
            errorMessage = error.localizedDescription
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Identity

    /// Attach RevenueCat to a signed-in user so their purchases follow them
    /// across devices/reinstalls. Call this after sign-in. Best-effort: a
    /// failed logIn must not block the app, so we swallow the error and still
    /// refresh entitlements (which fall back to the anonymous identity).
    func identify(_ userID: String) async {
        _ = try? await Purchases.shared.logIn(userID)
        await refreshCustomerInfo()
    }

    // MARK: - Restore

    @discardableResult
    func restorePurchases() async -> RestoreOutcome {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPro = Self.hasProEntitlement(in: info)
            return isPro ? .restored : .nothingToRestore
        } catch {
            errorMessage = error.localizedDescription
            return .failed(error.localizedDescription)
        }
    }
}

// MARK: - Purchases Delegate

private final class MooniPurchasesDelegate: NSObject, RevenueCat.PurchasesDelegate, @unchecked Sendable {
    static let shared = MooniPurchasesDelegate()
    private override init() {}

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            // Reuse the single source-of-truth entitlement check rather than
            // re-implementing it against the literal entitlement string.
            SubscriptionManager.shared.isPro = SubscriptionManager.hasProEntitlement(in: customerInfo)
        }
    }
}
