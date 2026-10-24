import Foundation
import StoreKit
import JohnCore

/// The one purchase in John 1:1: the full Fathers and Doctors library, bought once.
///
/// Access comes from three places, checked in this order:
/// 1. A cached answer in UserDefaults, so the library opens at once and offline.
/// 2. `Transaction.currentEntitlements` for a purchase (works offline from the device's receipt).
/// 3. `AppTransaction.shared` for people who installed before the purchase existed.
/// Grandfathering is sticky: once true it is never cleared. A purchase is cleared only when
/// StoreKit reports it revoked (a refund) or no longer lists it.
@MainActor @Observable final class FathersLibraryStore {
    enum Access: Equatable { case checking, locked, purchased, grandfathered }
    enum PurchaseState: Equatable { case idle, purchasing, pending, failed(String) }

    private(set) var access: Access
    private(set) var product: Product?
    private(set) var productLoadFailed = false
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var restoreMessage: String?

    var isUnlocked: Bool { access == .purchased || access == .grandfathered }
    var displayPrice: String? { product?.displayPrice }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var started = false
    /// Debug only: a launch argument fixed the state, so StoreKit must not change it.
    @ObservationIgnored private var forcedByLaunchArgument = false

    private static let purchasedKey = "john.fathers.purchased"
    private static let grandfatheredKey = "john.fathers.grandfathered"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.bool(forKey: Self.grandfatheredKey) { access = .grandfathered }
        else if defaults.bool(forKey: Self.purchasedKey) { access = .purchased }
        else { access = .checking }
        #if DEBUG
        // UI test and screenshot hook: -JohnFathersAccess locked|purchased|grandfathered
        if let forced = defaults.string(forKey: "JohnFathersAccess") {
            switch forced {
            case "locked": access = .locked; forcedByLaunchArgument = true
            case "purchased": access = .purchased; forcedByLaunchArgument = true
            case "grandfathered": access = .grandfathered; forcedByLaunchArgument = true
            default: break
            }
        }
        #endif
    }

    /// Starts the transaction listener once and refreshes access. Safe to call more than once.
    func start() {
        guard !started else { return }
        started = true
        if forcedByLaunchArgument { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case let .verified(transaction) = update,
                      transaction.productID == FathersLibraryAccess.productID else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
        Task { await refresh(); await loadProduct() }
    }

    func refresh() async {
        if forcedByLaunchArgument || access == .grandfathered { return }
        if await hasPurchase() {
            setPurchased(true)
            return
        }
        setPurchased(false)
        if await checkGrandfathered() {
            defaults.set(true, forKey: Self.grandfatheredKey)
            access = .grandfathered
        } else {
            access = .locked
        }
    }

    func loadProduct() async {
        guard product == nil else { return }
        do {
            product = try await Product.products(for: [FathersLibraryAccess.productID]).first
            productLoadFailed = product == nil
        } catch {
            productLoadFailed = true
        }
    }

    func purchase() async {
        if product == nil { await loadProduct() }
        guard let product else {
            purchaseState = .failed("The App Store could not be reached. Check your connection and try again.")
            return
        }
        purchaseState = .purchasing
        do {
            switch try await product.purchase() {
            case let .success(.verified(transaction)):
                await transaction.finish()
                setPurchased(true)
                purchaseState = .idle
            case .success(.unverified):
                purchaseState = .failed("The App Store could not verify the purchase. You were not charged twice; try Restore Purchases.")
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed("The purchase did not finish. Please try again.")
        }
    }

    func restore() async {
        restoreMessage = nil
        do { try await AppStore.sync() } catch {
            restoreMessage = "The App Store could not be reached. Check your connection and try again."
            return
        }
        await refresh()
        restoreMessage = isUnlocked ? "The full library is unlocked." : "No purchase was found for this Apple Account."
    }

    func clearPurchaseMessage() { if case .failed = purchaseState { purchaseState = .idle } }

    private func setPurchased(_ value: Bool) {
        defaults.set(value, forKey: Self.purchasedKey)
        if value { access = .purchased }
    }

    private func hasPurchase() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement,
                  transaction.productID == FathersLibraryAccess.productID,
                  transaction.revocationDate == nil else { continue }
            return true
        }
        return false
    }

    private func checkGrandfathered() async -> Bool {
        guard case let .verified(appTransaction) = try? await AppTransaction.shared else { return false }
        let environment: FathersLibraryAccess.DownloadEnvironment = switch appTransaction.environment {
        case .production: .production
        case .xcode: .xcode
        default: .sandbox
        }
        return FathersLibraryAccess.isGrandfathered(originalAppVersion: appTransaction.originalAppVersion,
                                                    environment: environment)
    }
}
