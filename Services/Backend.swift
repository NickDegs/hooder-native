import Foundation
import Observation

// ── Backend modelleri ─────────────────────────────────────────────────────────
struct LeaderEntry: Decodable, Identifiable {
    let id: String
    let name: String
    let netWorth: Double
}
struct Auction: Decodable, Identifiable {
    let id: String
    let propertyName: String
    let currentBid: Double
    let startPrice: Double
    let bidderName: String?
    let endsAt: TimeInterval   // unix saniye
}

// ── Backend servisi (liderlik + açık artırma + transfer) ──────────────────────
// Sunucu varsa canlı; yoksa sessizce son hâli/yerel veriyle çalışır (offline-tolerant).
@MainActor
@Observable
final class BackendService {
    static let shared = BackendService()

    var baseURL = URL(string: "https://realvirtuality.app/hooder-api")!
    var token: String?

    private(set) var leaders: [LeaderEntry] = []
    private(set) var auctions: [Auction] = []
    private(set) var online = false

    func refresh() async {
        await loadLeaders()
        await loadAuctions()
    }

    func loadLeaders() async {
        guard let data = await get("leaderboard") else { online = false; return }
        if let list = try? JSONDecoder().decode([LeaderEntry].self, from: data) {
            leaders = list.sorted { $0.netWorth > $1.netWorth }; online = true
        }
    }

    func loadAuctions() async {
        guard let data = await get("auctions") else { return }
        if let list = try? JSONDecoder().decode([Auction].self, from: data) { auctions = list }
    }

    /// Kendi net değerini gönder (liderlik tablosuna girsin)
    func submitScore(name: String, netWorth: Double) async {
        let body = ["name": name, "netWorth": netWorth] as [String: Any]
        _ = await post("score", json: body)
    }

    /// Açık artırmada teklif ver
    @discardableResult
    func bid(auctionId: String, amount: Double) async -> Bool {
        let ok = await post("auctions/\(auctionId)/bid", json: ["amount": amount]) != nil
        if ok { await loadAuctions() }
        return ok
    }

    // ── HTTP yardımcıları ─────────────────────────────────────────────────────
    private func get(_ path: String) async -> Data? {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.timeoutInterval = 10
        req.setValue(AppSecret.hooderKey, forHTTPHeaderField: "X-Hooder-Key")
        if let token = token ?? AuthService.shared.token { req.setValue(token, forHTTPHeaderField: "X-Auth-Token") }
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode ?? 500 < 400 else { return nil }
            return data
        } catch { return nil }
    }

    private func post(_ path: String, json: [String: Any]) async -> Data? {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AppSecret.hooderKey, forHTTPHeaderField: "X-Hooder-Key")
        if let token = token ?? AuthService.shared.token { req.setValue(token, forHTTPHeaderField: "X-Auth-Token") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: json)
        req.timeoutInterval = 10
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode ?? 500 < 400 else { return nil }
            return data
        } catch { return nil }
    }
}
