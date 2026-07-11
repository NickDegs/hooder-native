import Foundation
import CoreLocation
import Observation

// ── Tanıtım sinyalleri: offline tile'lar hazır olunca orbit BUNU bekler ──────────
// Sabit süre beklemek yerine (bazı şehirlerde tile'lar geç iniyor → boş harita üzerinde
// orbit) gerçek "hazır" sinyaliyle senkronize olur. Böylece her şehir dolu render'da döner.
@MainActor @Observable final class DemoSignals {
    static let shared = DemoSignals()
    var tilesReady = false
}

// ── Otomatik tanıtım / tur modu ───────────────────────────────────────────────
// Yalnız `-demo` argümanıyla açılır (App Store önizleme + reklam videosu çekimi için).
// Normal kullanıcıyı ETKİLEMEZ. Snapshot'tan farkı: gerçek kimlik/harita/cüzdan yükler,
// sonra sekmeler + kamera arasında akıcı bir tur yapar (RootView.runDemo).
enum Demo {
    static var active: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    // Tanıtım dili: `-demoLang tr` → L10n'e uygulanır (Snapshot'a dokunmadan)
    static var lang: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demoLang"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    // Çekim bypass anahtarı: `-demoKey <KEY>` → /anon'a X-Hooder-Demo başlığı (attest'i atlar).
    // Yalnız simülatör kaydında kullanılır; repo'da gömülü DEĞİL, CI secret'ından gelir.
    static var key: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demoKey"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    // Tanıtımda uçulacak ikonik dünya merkezleri (varsayılan: Manhattan)
    static let newYork  = CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.9840) // Manhattan

    // Lokalize önizleme: `-demoLat 48.8584 -demoLng 2.2945` → o şehre uç.
    // Her dilin App Store önizlemesi kendi ikonik şehrini gösterir (14 ayrı video).
    static var cityCenter: CLLocationCoordinate2D? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demoLat"), i + 1 < args.count,
              let j = args.firstIndex(of: "-demoLng"), j + 1 < args.count,
              let lat = Double(args[i + 1]), let lng = Double(args[j + 1]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
