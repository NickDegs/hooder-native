import Foundation
import Observation

// ── Canlı ekonomi simülasyonu ─────────────────────────────────────────────────
// • Döviz kurları gerçek API'den tohumlanır (open.er-api), sonra her tick'te küçük
//   drift ile CANLI değişir (oyun-içi sanal piyasa).
// • marketIndex: mülk fiyatlarını canlı dalgalandıran piyasa endeksi (~1.0).
// • recordTrade: oyuncu alım/satımları endeksi iter → "ekonomik savaş" (aksiyon → ekonomi).
@MainActor
@Observable
final class EconomyService {
    static let shared = EconomyService()

    // 1 USD = X birim (yerel para)
    var rates: [String: Double] = ["EUR": 0.92, "GBP": 0.79, "JPY": 150, "TRY": 34,
                                   "CNY": 7.2, "AED": 3.67, "CHF": 0.88, "CAD": 1.36]
    var prevRates: [String: Double] = [:]
    var marketIndex: Double = 1.0          // mülk fiyat çarpanı (canlı)
    var prevIndex: Double = 1.0

    let currencies: [(code: String, flag: String, name: String)] = [
        ("EUR", "🇪🇺", "Euro"), ("GBP", "🇬🇧", "Sterlin"), ("JPY", "🇯🇵", "Yen"),
        ("TRY", "🇹🇷", "Lira"), ("CNY", "🇨🇳", "Yuan"), ("AED", "🇦🇪", "Dirhem"),
        ("CHF", "🇨🇭", "Frank"), ("CAD", "🇨🇦", "Kanada $"),
    ]

    private var timer: Timer?
    private var seeded = false

    func start() {
        guard timer == nil else { return }
        prevRates = rates
        Task { await seed() }
        // Her 3 sn'de canlı drift
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    func stop() { timer?.invalidate(); timer = nil }

    // Gerçek kurlarla tohumla (başarısızsa varsayılanlar kalır)
    private func seed() async {
        guard !seeded else { return }
        if let url = URL(string: "https://open.er-api.com/v6/latest/USD"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let j = try? JSONDecoder().decode(ERAPILatest.self, from: data) {
            for c in currencies { if let r = j.rates[c.code] { rates[c.code] = r } }
            prevRates = rates
        }
        seeded = true
    }

    // Canlı drift: kurlar + piyasa endeksi küçük rastgele oynar
    private func tick() {
        prevRates = rates
        for (k, v) in rates {
            let d = Double.random(in: -0.004...0.004)   // ±%0.4
            rates[k] = max(0.0001, v * (1 + d))
        }
        prevIndex = marketIndex
        marketIndex = clampIdx(marketIndex * (1 + Double.random(in: -0.006...0.006)))
    }

    // Oyuncu aksiyonu → ekonomiye baskı (büyük alım piyasayı ısıtır, satış soğutur)
    func recordTrade(buy: Bool, magnitude: Double) {
        let push = min(0.025, magnitude / 400_000_000) * (buy ? 1 : -1)
        prevIndex = marketIndex
        marketIndex = clampIdx(marketIndex + push)
    }

    func change(_ code: String) -> Double {   // kurun son tick değişimi (%)
        guard let now = rates[code], let prev = prevRates[code], prev > 0 else { return 0 }
        return (now - prev) / prev * 100
    }
    var indexChange: Double { prevIndex > 0 ? (marketIndex - prevIndex) / prevIndex * 100 : 0 }

    private func clampIdx(_ x: Double) -> Double { max(0.6, min(1.7, x)) }
}

struct ERAPILatest: Decodable { let rates: [String: Double] }
