import Foundation
import CoreLocation
import Observation

// ── Konum yöneticisi ──────────────────────────────────────────────────────────
// "Konumuma git" butonu için: izni İLK BASIŞTA ister, tek seferlik konum alır,
// onFix ile haritaya bildirir. Başka zaman GPS çağrılmaz.
@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let mgr = CLLocationManager()
    var coordinate: CLLocationCoordinate2D?
    var onFix: ((CLLocationCoordinate2D) -> Void)?
    var denied = false

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Butona basınca: izin iste + konumu al.
    func requestAndLocate() {
        let st = mgr.authorizationStatus
        if st == .denied || st == .restricted { denied = true; return }
        if st == .notDetermined { mgr.requestWhenInUseAuthorization() }  // izin sorulur
        else { mgr.requestLocation() }                                   // zaten izinli → al
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let c = locs.last?.coordinate else { return }
        Task { @MainActor in self.coordinate = c; self.onFix?(c) }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) { }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let st = m.authorizationStatus
        Task { @MainActor in
            if st == .authorizedWhenInUse || st == .authorizedAlways { m.requestLocation() }
            else if st == .denied || st == .restricted { self.denied = true }
        }
    }
}
