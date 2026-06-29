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

    /// Mülk başka bir oyuncunun (rakip) elinde mi? (oyuncu sahibi değilse)
    func rivalOwned(_ p: Property) -> Bool { !isOwned(p.id) && Rivals.owner(of: p) != nil }

    /// Doğrudan satın alınabilir mi? (VIP kilidi yok + rakip elinde değil)
    func canBuy(_ p: Property) -> Bool { (!p.vipOnly || isVIP) && !rivalOwned(p) }

    /// Rakibe teklif → kabul edilirse mülk devralınır. Kabul eşiği: fiyatın %15 üstü.
    /// Dönüş: 0=yetersiz/geçersiz, 1=kabul (devralındı), 2=reddedildi
    func makeOffer(_ p: Property, amount: Double) -> Int {
        guard !isOwned(p.id), amount > 0 else { return 0 }
        let floor = livePrice(p) * 1.15
        if amount < floor { return 2 }            // düşük teklif → red
        guard cash >= amount else { return 0 }     // bakiye yetmez
        cash -= amount
        ownedIds.insert(p.id)
        save()
        return 1
    }

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
