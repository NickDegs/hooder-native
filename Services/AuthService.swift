import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

// ── Anonim cihaz kimliği ───────────────────────────────────────────────────────
// Şifre/eposta YOK. Cihazdan kararlı bir device_id türetilir, sunucudan token alınır.
// Token tüm SUNUCU-OTORİTER cüzdan çağrılarında kullanılır (al/sat/fx/wallet).
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var token: String?
    private(set) var ready = false      // sunucu kimliği alındı mı → OYUN KİLİDİ
    private let base = URL(string: "https://realvirtuality.app/hooder-api")!

    /// OYUN KİLİDİ: internet + sunucu kimliği ZORUNLU. Token alınınca açılır.
    /// Korsan/sideload veya offline durumda token alınamaz → oyun açılmaz.
    func authenticate() async {
        ready = (await ensure()) != nil
    }

    /// CI ekran görüntüsü modunda kapıyı atla (gerçek kullanıcıyı etkilemez).
    func markReadyForSnapshot() { ready = true }

    /// Kararlı cihaz kimliği (ilk açılışta üretilir, kalıcı saklanır).
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

    /// Token'ı garanti et (yoksa /anon ile al). Açılışta çağrılır; offline ise sessizce geçer.
    @discardableResult
    func ensure() async -> String? {
        if let token { return token }
        var req = URLRequest(url: base.appendingPathComponent("anon"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AppSecret.hooderKey, forHTTPHeaderField: "X-Hooder-Key")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["device_id": deviceID()])
        req.timeoutInterval = 10
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode ?? 500 < 400,
              let j = try? JSONDecoder().decode(AnonResp.self, from: data) else { return nil }
        token = j.token
        return token
    }
}

private struct AnonResp: Decodable { let token: String; let uid: String? }
