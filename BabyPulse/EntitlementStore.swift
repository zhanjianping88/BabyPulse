//
//  EntitlementStore.swift
//  BabyPulse
//
//  Created by Codex on 2026/3/26.
//

import Combine
import Foundation
import StoreKit

enum PremiumFeature: String, Identifiable {
    case unlimitedHistory
    case advancedStats
    case smartReminders
    case familySharing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedHistory: "Unlimited History"
        case .advancedStats: "Advanced Stats"
        case .smartReminders: "Smart Reminders"
        case .familySharing: "Shared Tracker Import"
        }
    }

    var subtitle: String {
        switch self {
        case .unlimitedHistory: "Unlock all past sleep, feed, and diaper records beyond 7 days."
        case .advancedStats: "See trends, routines, and rolling summaries instead of only basic totals."
        case .smartReminders: "Get local reminders after feeds and during active sleep sessions."
        case .familySharing: "Move a one-time tracker snapshot to another phone with a shared code."
        }
    }
}

enum PurchaseState: Equatable {
    case idle
    case loadingProducts
    case purchasing
    case restoring
}

@MainActor
final class EntitlementStore: ObservableObject {
    static let premiumAccessGroupName = "Premium Access"
    static let premiumWeeklyProductID = "com.jianping.BabyPulse.premium.weekly"

    @Published private(set) var hasPro = false {
        didSet {
            UserDefaults.standard.set(hasPro, forKey: hasProCacheKey)
        }
    }
    @Published var presentedFeature: PremiumFeature?
    @Published private(set) var weeklyProduct: Product?
    @Published private(set) var purchaseState: PurchaseState = .loadingProducts
    @Published var storeErrorMessage: String?

    let freeHistoryDays = 7

    private let hasProCacheKey = "BabyPulse.hasPro.cached"
    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        self.hasPro = UserDefaults.standard.bool(forKey: hasProCacheKey)
        transactionUpdatesTask = observeTransactionUpdates()

        Task {
            await refreshStoreState()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var weeklyPriceText: String {
        weeklyProduct?.displayPrice ?? "$2.99"
    }

    var isBusy: Bool {
        purchaseState == .loadingProducts || purchaseState == .purchasing || purchaseState == .restoring
    }

    func presentPaywall(for feature: PremiumFeature) {
        presentedFeature = feature
        storeErrorMessage = nil

        Task {
            await loadProductsIfNeeded()
        }
    }

    func loadProductsIfNeeded() async {
        guard weeklyProduct == nil else { return }
        await loadProducts()
    }

    func purchaseWeekly() async -> Bool {
        await loadProductsIfNeeded()

        guard let weeklyProduct else {
            storeErrorMessage = "Unable to load the subscription product right now."
            return false
        }

        purchaseState = .purchasing
        defer {
            if purchaseState == .purchasing {
                purchaseState = .idle
            }
        }

        do {
            let result = try await weeklyProduct.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                purchaseState = .idle
                storeErrorMessage = nil
                return hasPro
            case .pending:
                storeErrorMessage = "Purchase is pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                storeErrorMessage = "Purchase was not completed."
                return false
            }
        } catch {
            storeErrorMessage = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async {
        purchaseState = .restoring
        defer {
            if purchaseState == .restoring {
                purchaseState = .idle
            }
        }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            storeErrorMessage = nil
        } catch {
            storeErrorMessage = error.localizedDescription
        }
    }

    func refreshStoreState() async {
        await loadProducts()
        await refreshEntitlements()
    }

    private func loadProducts() async {
        purchaseState = .loadingProducts
        defer {
            if purchaseState == .loadingProducts {
                purchaseState = .idle
            }
        }

        do {
            let products = try await Product.products(for: [Self.premiumWeeklyProductID])
            weeklyProduct = products.first

            if weeklyProduct == nil {
                storeErrorMessage = "Subscription product not found in App Store Connect."
            }
        } catch {
            storeErrorMessage = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var subscriptionIsActive = false

        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(entitlement) else { continue }
            guard transaction.productID == Self.premiumWeeklyProductID else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard transaction.expirationDate.map({ $0 > .now }) ?? true else { continue }

            subscriptionIsActive = true
            break
        }

        hasPro = subscriptionIsActive
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                do {
                    let transaction = try Self.checkVerified(update)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    await MainActor.run {
                        self.storeErrorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let signedType):
            return signedType
        case .unverified:
            throw StoreError.failedVerification
        }
    }
}

enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            "App Store purchase verification failed."
        }
    }
}
