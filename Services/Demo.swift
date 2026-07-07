import Foundation
import CoreLocation

// ── Otomatik tanıtım / tur modu ───────────────────────────────────────────────
// Yalnız `-demo` argümanıyla açılır (App Store önizleme + reklam videosu çekimi için).
// Normal kullanıcıyı ETKİLEMEZ. Snapshot'tan farkı: gerçek kimlik/harita/cüzdan yükler,
// sonra sekmeler + kamera arasında akıcı bir tur yapar (RootView.runDemo).
enum Demo {
    static var active: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    // Tanıtımda uçulacak ikonik dünya merkezleri
    static let istanbul = CLLocationCoordinate2D(latitude: 41.0256, longitude: 28.9744)  // Boğaz
    static let newYork  = CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.9840) // Manhattan
    static let paris    = CLLocationCoordinate2D(latitude: 48.8584, longitude: 2.2945)   // Eyfel
    static let dubai    = CLLocationCoordinate2D(latitude: 25.1972, longitude: 55.2744)  // Burj Khalifa
}
