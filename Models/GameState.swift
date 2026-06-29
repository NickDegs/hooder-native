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
    private(set) var fx: [String: FXPosition] = [:]   // döviz pozisyonları

    // VIP avantajları
    var incomeMultiplier: Double { isVIP ? 1.25 : 1.0 }   // +%25 günlük gelir
    var vipDiscount: Double { isVIP ? 0.90 : 1.0 }        // VIP: %10 indirim

    private let store = UserDefaults.standard

    init() { load() }

    var level: Int { max(1, Int(log2(max(1, netWorth / 5_000_000))) + 1) }

    // Net değer: nakit + mülkler (canlı piyasa değeriyle) + döviz pozisyonları
    var netWorth: Double {
        let idx = EconomyService.shared.marketIndex
        let propVal = PropertyFeed.shared.all.filter { ownedIds.contains($0.id) }.reduce(0) { $0 + $1.price * idx }
        let fxVal = fx.reduce(0.0) { acc, kv in
            let rate = EconomyService.shared.rates[kv.key] ?? 0
            return acc + (rate > 0 ? kv.value.units / rate : 0)
        }
        return cash + propVal + fxVal
    }

    func isOwned(_ id: String) -> Bool { ownedIds.contains(id) }

    /// Canlı fiyat: temel × talep primi × VIP indirim × PİYASA ENDEKSİ (canlı dalgalanır).
    func livePrice(_ p: Property) -> Double {
        let premium = 1 + Double(ownedIds.count) * 0.012
        return (p.price * premium * vipDiscount * EconomyService.shared.marketIndex).rounded()
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
        EconomyService.shared.recordTrade(buy: true, magnitude: amount)
        save()
        return 1
    }

    @discardableResult
    func buy(_ p: Property) -> Bool {
        let cost = livePrice(p)
        guard canBuy(p), !isOwned(p.id), cash >= cost else { return false }
        cash -= cost
        ownedIds.insert(p.id)
        EconomyService.shared.recordTrade(buy: true, magnitude: cost)   // alım → piyasayı ısıt
        save()
        return true
    }

    // ── Döviz (Forex) — canlı kurla al/sat ────────────────────────────────────
    /// usdAmount nakitle, rate (1 USD = rate birim) → units alınır.
    @discardableResult
    func buyFx(_ code: String, usdAmount: Double, rate: Double) -> Bool {
        guard usdAmount > 0, rate > 0, cash >= usdAmount else { return false }
        let prev = fx[code] ?? FXPosition(units: 0, costUSD: 0)
        fx[code] = FXPosition(units: prev.units + usdAmount * rate, costUSD: prev.costUSD + usdAmount)
        cash -= usdAmount
        save()
        return true
    }
    /// Pozisyonu güncel kurla USD'ye çevir → gerçekleşen K/Z döner (NaN: pozisyon yok).
    @discardableResult
    func sellFx(_ code: String, rate: Double) -> Double {
        guard let pos = fx[code], pos.units > 0, rate > 0 else { return .nan }
        let usd = pos.units / rate
        let pl = usd - pos.costUSD
        fx[code] = nil
        cash += usd
        save()
        return pl
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
        fx = [:]
        save()
    }

    // Kalıcılık
    private func save() {
        store.set(cash, forKey: "cash")
        store.set(Array(ownedIds), forKey: "ownedIds")
        if let d = try? JSONEncoder().encode(fx) { store.set(d, forKey: "fx") }
    }
    private func load() {
        if store.object(forKey: "cash") != nil { cash = store.double(forKey: "cash") }
        if let a = store.array(forKey: "ownedIds") as? [String] { ownedIds = Set(a) }
        if let d = store.data(forKey: "fx"), let f = try? JSONDecoder().decode([String: FXPosition].self, from: d) { fx = f }
    }
}

struct FXPosition: Codable, Equatable {
    var units: Double      // sahip olunan döviz birimi
    var costUSD: Double    // maliyet (USD)
}
