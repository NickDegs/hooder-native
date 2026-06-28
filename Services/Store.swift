import Foundation
import StoreKit
import Observation

// ── StoreKit 2 IAP — nakit paketleri ──────────────────────────────────────────
// Consumable nakit paketleri. Kredi DOĞRUDAN işlem (transaction) olayından verilir
// (Ask-to-Buy / kesinti / yeniden açılışta bile teslim) → 2.1(b) güvenli.
@MainActor
@Observable
final class Store {
    // Ürün kimliği → verilecek nakit (App Store Connect'te bu id'lerle tanımla)
    static let cashFor: [String: Double] = [
        "com.realvirtuality.hooder.cash.starter":  1_500_000,
        "com.realvirtuality.hooder.cash.investor": 5_000_000,
        "com.realvirtuality.hooder.cash.tycoon":  20_000_000,
        "com.realvirtuality.hooder.cash.mogul":   75_000_000,
    ]

    var products: [Product] = []
    var purchasingId: String?
    var lastCredited: Double?
    var onCredit: ((Double) -> Void)?

    private var updatesTask: Task<Void, Never>?
    private var credited: Set<String> = []   // çift kredi engeli (transaction id)

    init() { updatesTask = listenForTransactions() }

    func load() async {
        do {
            let p = try await Product.products(for: Array(Self.cashFor.keys))
            products = p.sorted { $0.price < $1.price }
        } catch { products = [] }
    }

    func buy(_ product: Product) async {
        purchasingId = product.id
        defer { purchasingId = nil }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    credit(transaction)
                    await transaction.finish()
                }
            case .userCancelled, .pending: break
            @unknown default: break
            }
        } catch { /* satın alma hatası */ }
    }

    /// Açılışta / Store görününce: bitmemiş (current entitlement) consumable'ları teslim et.
    func deliverPending() async {
        for await result in Transaction.unfinished {
            if case .verified(let t) = result { credit(t); await t.finish() }
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let t) = update {
                    await self?.creditOnMain(t)
                    await t.finish()
                }
            }
        }
    }

    private func creditOnMain(_ t: Transaction) async { credit(t) }

    private func credit(_ t: Transaction) {
        let key = "\(t.id)"
        guard !credited.contains(key) else { return }
        credited.insert(key)
        if let amount = Self.cashFor[t.productID] {
            lastCredited = amount
            onCredit?(amount)
        }
    }
}
