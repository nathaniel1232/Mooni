import Foundation
import Combine
import RevenueCat

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // MARK: - Published

    /// Sourced from RevenueCat at launch (with the `devForcePro` override
    /// taking precedence). Intentionally not persisted — entitlement status
    /// is the source of truth and is re-fetched on app start.
    @Published var isPro: Bool = false
    @Published var currentOffering: Offering?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Local override that flips the app into Pro for testing without a sandbox
    /// purchase. Persisted across launches so the rest of the app behaves
    /// exactly as if the user owns the entitlement.
    @Published var devForcePro: Bool {
        didSet {
            UserDefaults.standard.set(devForcePro, forKey: "mooni.devForcePro")
            if devForcePro { isPro = true }
            else { Task { await refreshCustomerInfo() } }
        }
    }

    private init() {
        self.devForcePro = UserDefaults.standard.bool(forKey: "mooni.devForcePro")
        if self.devForcePro { self.isPro = true }
    }

    // MARK: - Configuration

    func configure() {
        Purchases.logLevel = .error
        Purchases.configure(withAPIKey: "test_ZLGdnSIgtxLglPKmaWsNnGXtYvn")
        Purchases.shared.delegate = MooniPurchasesDelegate.shared
        Task { await refreshAll() }
    }

    // MARK: - Data loading

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshCustomerInfo() }
            group.addTask { await self.loadOfferings() }
        }
    }

    func refreshCustomerInfo() async {
        if devForcePro { isPro = true; return }
        do {
            let info = try await Purchases.shared.customerInfo()
            isPro = info.entitlements.active["SleepOwl Pro"] != nil
        } catch {
            // Silently fail — no internet or sandbox; treat as non-pro
        }
    }

    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
        } catch {
            // Silently fail — UI will show fallback state
        }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(package: Package) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                await refreshCustomerInfo()
                // Defensive: if the entitlement check came back empty in sandbox
                // but the purchase did NOT report cancellation, treat the user
                // as Pro for this session so premium features actually unlock.
                if !isPro { isPro = true }
                return true
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPro = info.entitlements.active["SleepOwl Pro"] != nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Purchases Delegate

private final class MooniPurchasesDelegate: NSObject, RevenueCat.PurchasesDelegate, @unchecked Sendable {
    static let shared = MooniPurchasesDelegate()
    private override init() {}

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            SubscriptionManager.shared.isPro = customerInfo.entitlements.active["SleepOwl Pro"] != nil
        }
    }
}
