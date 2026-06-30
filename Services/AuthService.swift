import Foundation
import Observation
import CryptoKit
import DeviceCheck
#if canImport(UIKit)
import UIKit
#endif

// ── Anonim cihaz kimliği + Apple App Attest (korsan/tamper engeli) ──────────────
// Şifre/eposta YOK. Cihazdan kararlı device_id; App Attest ile uygulamanın GERÇEK
// (App Store'dan, değiştirilmemiş, gerçek cihaz) olduğu sunucuda kanıtlanır.
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var token: String?
    private(set) var ready = false      // sunucu kimliği alındı mı → OYUN KİLİDİ
    private let base = URL(string: "https://realvirtuality.app/hooder-api")!
    private let attest = DCAppAttestService.shared

    func authenticate() async { ready = (await ensure()) != nil }
    func markReadyForSnapshot() { ready = true }

    private func deviceID() -> String {
        if let s = UserDefaults.standard.string(forKey: "hooder_device_id"), s.count >= 8 { return s }
        #if canImport(UIKit)
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        let id = UUID().uuidString
        #endif
        UserDefaults.standard.set(id, forKey: "hooder_device_id")
        return id
    }

    @discardableResult
    func ensure() async -> String? {
        if let token { return token }
        var body: [String: Any] = ["device_id": deviceID(), "platform": "ios"]
        // App Attest destekliyse uygulamanın gerçekliğini kanıtla (simülatör desteklemez → atla)
        if attest.isSupported, let proof = await attestProof() {
            body.merge(proof) { _, n in n }
        }
        guard let req = post("anon", body),
              let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode ?? 500 < 400,
              let j = try? JSONDecoder().decode(AnonResp.self, from: data) else { return nil }
        token = j.token
        return token
    }

    // App Attest kanıtı: ilk açılışta attestation, sonraki açılışlarda assertion
    private func attestProof() async -> [String: Any]? {
        guard let challenge = await fetchChallenge() else { return nil }
        let clientHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let storedKey = UserDefaults.standard.string(forKey: "hooder_attest_key")
        do {
            if let keyId = storedKey {
                let assertion = try await attest.generateAssertion(keyId, clientDataHash: clientHash)
                return ["challenge": challenge, "key_id": keyId, "assertion": assertion.base64EncodedString()]
            } else {
                let keyId = try await attest.generateKey()
                let attestation = try await attest.attestKey(keyId, clientDataHash: clientHash)
                UserDefaults.standard.set(keyId, forKey: "hooder_attest_key")
                return ["challenge": challenge, "key_id": keyId, "attestation": attestation.base64EncodedString()]
            }
        } catch { return nil }   // başarısız → kanıtsız dene (sunucu flag'ine göre karar verir)
    }

    private func fetchChallenge() async -> String? {
        guard let req = post("attest/challenge", [:]),
              let (data, _) = try? await URLSession.shared.data(for: req),
              let j = try? JSONDecoder().decode(ChallengeResp.self, from: data) else { return nil }
        return j.challenge
    }

    private func post(_ path: String, _ body: [String: Any]) -> URLRequest? {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AppSecret.hooderKey, forHTTPHeaderField: "X-Hooder-Key")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 12
        return req
    }
}

private struct AnonResp: Decodable { let token: String; let uid: String? }
private struct ChallengeResp: Decodable { let challenge: String }
