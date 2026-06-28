import Foundation
import Observation

// ── Oyun durumu (Swift 6 @Observable) ─────────────────────────────────────────
// Nakit, sahip olunan mülkler, net değer, satın alma. Yerelde saklanır (UserDefaults).
@MainActor
@Observable
final class GameState {
    var cash: Double = 15_000_000
    private(set) var ownedIds: Set<String> = []
    private(set) var pendingIncome: Double = 0
    var isVIP: Bool = false          // aktif VIP aboneliği (StoreKit entitlement'tan)

    // VIP avantajları
    var incomeMultiplier: Double { isVIP ? 1.25 : 1.0 }   // +%25 günlük gelir
    var vipDiscount: Double { isVIP ? 0.90 : 1.0 }        // VIP: %10 indirim

    private let store = UserDefaults.standard

    init() { load() }

    var level: Int { max(1, Int(log2(max(1, netWorth / 5_000_000))) + 1) }

    var netWorth: Double {
        cash + PropertyFeed.shared.all.filter { ownedIds.contains($0.id) }.reduce(0) { $0 + $1.price }
    }

    func isOwned(_ id: String) -> Bool { ownedIds.contains(id) }

    /// Ownership premium: ne kadar çok mülk → fiyatlar hafif artar (talep). VIP %10 indirim.
    func livePrice(_ p: Property) -> Double {
        let premium = 1 + Double(ownedIds.count) * 0.012
        return (p.price * premium * vipDiscount).rounded()
    }

    /// VIP olmayan bir oyuncu vipOnly mülkü alamaz
    func canBuy(_ p: Property) -> Bool { !p.vipOnly || isVIP }

    @discardableResult
    func buy(_ p: Property) -> Bool {
        let cost = livePrice(p)
        guard canBuy(p), !isOwned(p.id), cash >= cost else { return false }
        cash -= cost
        ownedIds.insert(p.id)
        save()
        return true
    }

    /// Sahip olunan mülklerden günlük gelir tahakkuku (saniyede bir App tetikler)
    func tickIncome(_ dt: TimeInterval) {
        let perSec = PropertyFeed.shared.all
            .filter { ownedIds.contains($0.id) }
            .reduce(0) { $0 + $1.incomePerDay } / 86_400 * incomeMultiplier
        pendingIncome += perSec * dt
        if pendingIncome >= 1 {
            cash += pendingIncome.rounded(.down)
            pendingIncome -= pendingIncome.rounded(.down)
            save()
        }
    }

    /// IAP / ödül → nakit ekle
    func credit(_ amount: Double) {
        cash += amount
        save()
    }

    func reset() {
        cash = 15_000_000
        ownedIds = []
        pendingIncome = 0
        save()
    }

    // Kalıcılık
    private func save() {
        store.set(cash, forKey: "cash")
        store.set(Array(ownedIds), forKey: "ownedIds")
    }
    private func load() {
        if store.object(forKey: "cash") != nil { cash = store.double(forKey: "cash") }
        if let a = store.array(forKey: "ownedIds") as? [String] { ownedIds = Set(a) }
    }
}
