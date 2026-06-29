import Foundation
import StoreKit
import Observation

// ── StoreKit 2 IAP — nakit paketleri ──────────────────────────────────────────
// Consumable nakit paketleri. Kredi DOĞRUDAN işlem (transaction) olayından verilir
// (Ask-to-Buy / kesinti / yeniden açılışta bile teslim) → 2.1(b) güvenli.
@MainActor
@Observable
final class Store {
    static let shared = Store()

    // Ürün kimliği → verilecek nakit. ASC'de ZATEN TANIMLI 5 consumable (PWA'dan).
    static let cashFor: [String: Double] = [
        "app.realvirtuality.landlord.starter":   1_500_000,
        "app.realvirtuality.landlord.investor":  5_000_000,
        "app.realvirtuality.landlord.tycoon":   20_000_000,
        "app.realvirtuality.landlord.mogul":    75_000_000,
        "app.realvirtuality.landlord.empire":  250_000_000,
    ]

    // VIP abonelik ürün kimlikleri (ASC'de tanımlı auto-renewable)
    static let vipIds: Set<String> = [
        "app.realvirtuality.landlord.vip.monthly",
        "app.realvirtuality.landlord.vip.yearly",
    ]

    var products: [Product] = []        // consumable nakit paketleri
    var vipProducts: [Product] = []     // VIP abonelikleri
    var purchasingId: String?
    var lastCredited: Double?
    var isVIP: Bool = false
    var onCredit: ((Double) -> Void)?
    var onVIP: ((Bool) -> Void)?
    var onGrant: ((String) -> Void)?      // imzalı işlem (jws) → sunucuda doğrulanıp kredilenir
    var onVIPProof: ((String) -> Void)?   // VIP abonelik imzası (jws) → sunucuda doğrulanır (gelir çarpanı)

    private var updatesTask: Task<Void, Never>?
    private var credited: Set<String> = []   // çift kredi engeli (transaction id)

    init() { updatesTask = listenForTransactions() }

    func load() async {
        do {
            let ids = Array(Self.cashFor.keys) + Array(Self.vipIds)
            let p = try await Product.products(for: ids)
            products    = p.filter { Self.cashFor[$0.id] != nil }.sorted { $0.price < $1.price }
            vipProducts = p.filter { Self.vipIds.contains($0.id) }.sorted { $0.price < $1.price }
        } catch { products = []; vipProducts = [] }
        await refreshVIP()
    }

    /// Aktif VIP aboneliği var mı? (StoreKit 2 currentEntitlements)
    func refreshVIP() async {
        var active = false
        var proofJWS: String?
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.vipIds.contains(t.productID),
               t.revocationDate == nil, (t.expirationDate ?? .distantFuture) > Date() {
                active = true
                proofJWS = result.jwsRepresentation     // imzalı kanıt → sunucuda doğrulanacak
            }
        }
        isVIP = active
        onVIP?(active)
        if let proofJWS { onVIPProof?(proofJWS) }        // SUNUCU otoriter VIP gelir çarpanı
    }

    func buy(_ product: Product) async {
        purchasingId = product.id
        defer { purchasingId = nil }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    credit(transaction, jws: verification.jwsRepresentation)
                    await transaction.finish()
                    await refreshVIP()        // VIP aboneliği ise entitlement güncellensin
                }
            case .userCancelled, .pending: break
            @unknown default: break
            }
        } catch { /* satın alma hatası */ }
    }

    /// Açılışta / Store görününce: bitmemiş (current entitlement) consumable'ları teslim et.
    func deliverPending() async {
        for await result in Transaction.unfinished {
            if case .verified(let t) = result { credit(t, jws: result.jwsRepresentation); await t.finish() }
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let t) = update {
                    await self?.creditOnMain(t, jws: update.jwsRepresentation)
                    await t.finish()
                    await self?.refreshVIP()
                }
            }
        }
    }

    private func creditOnMain(_ t: Transaction, jws: String) async { credit(t, jws: jws) }

    private func credit(_ t: Transaction, jws: String) {
        let key = "\(t.id)"
        guard !credited.contains(key) else { return }
        credited.insert(key)
        if let amount = Self.cashFor[t.productID] {
            lastCredited = amount
            onCredit?(amount)                       // yerel anlık geri bildirim (UX)
            onGrant?(jws)                            // SUNUCU otoriter: Apple imzasını doğrula + kredile
        }
    }
}
