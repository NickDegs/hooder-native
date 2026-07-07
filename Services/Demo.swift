import Foundation
import CoreLocation

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

    // Tanıtımda uçulacak ikonik dünya merkezleri
    static let istanbul = CLLocationCoordinate2D(latitude: 41.0256, longitude: 28.9744)  // Boğaz
    static let newYork  = CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.9840) // Manhattan
    static let paris    = CLLocationCoordinate2D(latitude: 48.8584, longitude: 2.2945)   // Eyfel
    static let dubai    = CLLocationCoordinate2D(latitude: 25.1972, longitude: 55.2744)  // Burj Khalifa
}
