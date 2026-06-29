import Foundation
import Observation

// ── TEK DÜNYA EKONOMİSİ (client) ──────────────────────────────────────────────
// Backend tüm ekonominin TEK kaynağı: piyasa endeksi + döviz kurları gerçek dünyadan
// beslenir, oyuncu işlemleri hepsini iter. Bu servis ortak değeri çeker (sync) ve
// alım/satım baskısını ortak havuza yollar. Tüm oyuncular AYNI ekonomiyi yaşar = savaş.
@MainActor
@Observable
final class EconomyService {
    static let shared = EconomyService()

    var rates: [String: Double] = ["EUR": 0.92, "GBP": 0.79, "JPY": 150, "TRY": 34,
                                   "CNY": 7.2, "AED": 3.67, "CHF": 0.88, "CAD": 1.36]
    var prevRates: [String: Double] = [:]
    var marketIndex: Double = 1.0
    var prevIndex: Double = 1.0
    var online = false

    let currencies: [(code: String, flag: String, name: String)] = [
        ("EUR", "🇪🇺", "Euro"), ("GBP", "🇬🇧", "Sterlin"), ("JPY", "🇯🇵", "Yen"),
        ("TRY", "🇹🇷", "Lira"), ("CNY", "🇨🇳", "Yuan"), ("AED", "🇦🇪", "Dirhem"),
        ("CHF", "🇨🇭", "Frank"), ("CAD", "🇨🇦", "Kanada $"),
    ]

    private let base = URL(string: "https://realvirtuality.app/hooder-api")!
    private var timer: Timer?
    private var ticks = 0

    func start() {
        guard timer == nil else { return }
        prevRates = rates
        Task { await sync() }
        // Her 3 sn ortak ekonomiyi senkronla (endeks + kurlar canlı, herkes aynı)
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    func stop() { timer?.invalidate(); timer = nil }

    // Ortak ekonomiyi sunucudan çek (piyasa endeksi + GERÇEK döviz kurları, paylaşılan)
    func sync() async {
        guard let (data, _) = try? await URLSession.shared.data(from: base.appendingPathComponent("economy")),
              let j = try? JSONDecoder().decode(EconResp.self, from: data) else { online = false; return }
        prevIndex = marketIndex; marketIndex = clampIdx(j.index)
        if let r = j.rates, !r.isEmpty { prevRates = rates; rates = r }
        online = true
    }

    private func tick() {
        ticks += 1
        Task { await sync() }
        if !online {   // sunucu yoksa yerel endeks drift'i (kurlar son hâliyle kalır)
            prevIndex = marketIndex
            marketIndex = clampIdx(marketIndex * (1 + Double.random(in: -0.006...0.006)))
        }
    }

    // Mülk alım/satımı → ORTAK piyasa endeksini iter (anlık + sunucu)
    func recordTrade(buy: Bool, magnitude: Double) {
        let push = min(0.025, magnitude / 400_000_000) * (buy ? 1 : -1)
        prevIndex = marketIndex; marketIndex = clampIdx(marketIndex + push)
        post("economy/trade", ["buy": buy, "magnitude": magnitude]) { _ in }
    }

    // Döviz alım/satımı → ORTAK kuru iter (herkes aynı kuru görür)
    func recordFxTrade(code: String, usd: Double, buy: Bool) {
        post("economy/fx", ["code": code, "usd": usd, "buy": buy]) { [weak self] data in
            guard let self, let data,
                  let j = try? JSONDecoder().decode(FxResp.self, from: data), let r = j.rates, !r.isEmpty else { return }
            Task { @MainActor in self.prevRates = self.rates; self.rates = r }   // anlık güncelle
        }
    }

    private func post(_ path: String, _ body: [String: Any], _ done: @escaping (Data?) -> Void) {
        Task {
            var req = URLRequest(url: base.appendingPathComponent(path))
            req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body); req.timeoutInterval = 8
            let data = try? await URLSession.shared.data(for: req).0
            done(data)
        }
    }

    func change(_ code: String) -> Double {
        guard let now = rates[code], let prev = prevRates[code], prev > 0 else { return 0 }
        return (now - prev) / prev * 100
    }
    var indexChange: Double { prevIndex > 0 ? (marketIndex - prevIndex) / prevIndex * 100 : 0 }

    private func clampIdx(_ x: Double) -> Double { max(0.6, min(1.7, x)) }
}

struct EconResp: Decodable { let index: Double; let rates: [String: Double]? }
struct FxResp: Decodable { let rates: [String: Double]? }
