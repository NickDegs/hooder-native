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

// Referral (davet) durumu
struct ReferralInfo: Decodable {
    let code: String?
    let invited: Int
    let earned: Double
    let referrer_bonus: Double
    let invitee_bonus: Double
    let used_code: Bool
}

// Emlak Firması (klan)
struct Firm: Decodable, Identifiable {
    let id: String
    let name: String
    let emblem: String
    let members: Int
    let treasury: Double
    let netWorth: Double
}
struct FirmMember: Decodable, Identifiable {
    let uid: String
    let role: String
    let contributed: Double
    let isMe: Bool
    let cash: Double
    var id: String { uid }
}
struct MyFirm: Decodable {
    let firm: Firm?
    let role: String?
    let myContributed: Double?
    let myReceived: Double?
    let aidNet: Double?
    let aidTax: Double?
    let members: [FirmMember]?
}
private struct FirmsWrap: Decodable { let firms: [Firm] }

// Merkez Bankası (ülke)
struct Country: Decodable, Identifiable {
    let cc: String
    let name: String
    let flag: String
    let ccy: String
    var id: String { cc }
}
struct CountryStanding: Decodable, Identifiable {
    let cc: String
    let name: String
    let flag: String
    let ccy: String
    let power: Double
    let players: Int
    let treasury: Double
    let rank: Int
    var id: String { cc }
}
struct MyCountry: Decodable {
    let cc: String
    let name: String
    let flag: String
    let ccy: String
    let power: Double
    let players: Int
    let rank: Int
    let total: Int
    let treasury: Double
    let rate: Double?
}
private struct CountryListWrap: Decodable { let countries: [Country] }
private struct CountryBoardWrap: Decodable { let countries: [CountryStanding] }
private struct MyCountryWrap: Decodable { let country: MyCountry? }

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

    // ── Referral (davet) ───────────────────────────────────────────────────────
    /// Kendi davet kodun + kaç kişi davet ettin + toplam kazanç.
    func referralInfo() async -> ReferralInfo? {
        guard let data = await get("referral") else { return nil }
        return try? JSONDecoder().decode(ReferralInfo.self, from: data)
    }

    /// Başka birinin davet kodunu gir (bir kez): ikinize de nakit yansır.
    /// Dönen: (başarılı mı, hata mesajı anahtarı, kazanılan nakit).
    func redeemReferral(code: String) async -> (ok: Bool, reward: Double, error: String?) {
        guard let data = await post("referral/redeem", json: ["code": code]) else {
            return (false, 0, "referral_bad_code")
        }
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let ok = obj?["ok"] as? Bool, ok {
            return (true, (obj?["reward"] as? Double) ?? 0, nil)
        }
        return (false, 0, "referral_bad_code")
    }

    // ── Emlak Firması (klan) ───────────────────────────────────────────────────
    func firmMine() async -> MyFirm? {
        guard let data = await get("firm/mine") else { return nil }
        return try? JSONDecoder().decode(MyFirm.self, from: data)
    }
    func firmList() async -> [Firm] {
        guard let data = await get("firm/list") else { return [] }
        return (try? JSONDecoder().decode(FirmsWrap.self, from: data))?.firms ?? []
    }
    func firmLeaderboard() async -> [Firm] {
        guard let data = await get("firm/leaderboard") else { return [] }
        return (try? JSONDecoder().decode(FirmsWrap.self, from: data))?.firms ?? []
    }
    /// (başarılı mı, hata mesajı) — backend'in Türkçe hata metnini döndürür.
    func firmCreate(name: String, emblem: String) async -> (ok: Bool, error: String?) {
        let (code, data) = await postRaw("firm/create", json: ["name": name, "emblem": emblem])
        if code < 400 { return (true, nil) }
        return (false, errMsg(data))
    }
    func firmJoin(_ id: String) async -> Bool { await post("firm/join", json: ["firm_id": id]) != nil }
    func firmLeave() async -> Bool { await post("firm/leave", json: [:]) != nil }
    func firmContribute(_ amount: Double) async -> Bool { await post("firm/contribute", json: ["amount": amount]) != nil }
    /// (başarılı mı, alınan net, hata mesajı)
    func firmAid() async -> (ok: Bool, received: Double, error: String?) {
        let (code, data) = await postRaw("firm/aid", json: [:])
        if code < 400 {
            let obj = try? JSONSerialization.jsonObject(with: data ?? Data()) as? [String: Any]
            return (true, (obj?["received"] as? Double) ?? 0, nil)
        }
        return (false, 0, errMsg(data))
    }
    private func errMsg(_ data: Data?) -> String? {
        guard let data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["error"] as? String
    }

    // ── Merkez Bankası (ülke) ──────────────────────────────────────────────────
    func countryList() async -> [Country] {
        guard let data = await get("country/list") else { return [] }
        return (try? JSONDecoder().decode(CountryListWrap.self, from: data))?.countries ?? []
    }
    func countryMine() async -> MyCountry? {
        guard let data = await get("country/mine") else { return nil }
        return (try? JSONDecoder().decode(MyCountryWrap.self, from: data))?.country
    }
    func countryLeaderboard() async -> [CountryStanding] {
        guard let data = await get("country/leaderboard") else { return [] }
        return (try? JSONDecoder().decode(CountryBoardWrap.self, from: data))?.countries ?? []
    }
    func countryJoin(_ cc: String) async -> Bool { await post("country/join", json: ["cc": cc]) != nil }
    func countryContribute(_ amount: Double) async -> Bool { await post("country/contribute", json: ["amount": amount]) != nil }

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

    /// Ham POST — (statusCode, data). Backend hata metnini gerektiren çağrılar için.
    private func postRaw(_ path: String, json: [String: Any]) async -> (Int, Data?) {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AppSecret.hooderKey, forHTTPHeaderField: "X-Hooder-Key")
        if let token = token ?? AuthService.shared.token { req.setValue(token, forHTTPHeaderField: "X-Auth-Token") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: json)
        req.timeoutInterval = 10
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            return ((resp as? HTTPURLResponse)?.statusCode ?? 500, data)
        } catch { return (0, nil) }
    }
}
