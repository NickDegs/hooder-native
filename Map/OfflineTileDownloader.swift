import Foundation
import Observation
import MapboxMaps
import CoreLocation

// ── Otomatik offline döşeme indirici + KAYDIRMA PREFETCH ───────────────────────
// Uygulama ilk açıldığında bulunulan bölgenin UYDU döşemelerini + stil paketini indirir
// (TileStore + OfflineManager) → harita internetsiz, akıcı açılır. AYRICA harita gezerken
// merkezin düştüğü grid hücresi + 8 komşusu ARKA PLANDA sessizce iner (prefetch) → kaydırma
// hareketlerinde tile hep hazır, hiç kasmaz. Disk şişmesin diye LRU: en fazla maxCells hücre
// tutulur, en eskisi silinir. Etiketler (mülkler) backend'den ayrı ve canlı gelir.
@MainActor
@Observable
final class OfflineTileDownloader {

    enum Status: Equatable {
        case idle
        case downloading(Double)
        case ready
        case failed(String)
    }

    private(set) var status: Status = .idle {
        didSet {
            if Demo.active, case .ready = status { DemoSignals.shared.tilesReady = true }
        }
    }

    private let tileStore = TileStore.default
    private let offlineManager = OfflineManager()
    private var regionId = "home-region"
    private let styleURI: StyleURI = .satelliteStreets

    private var stylePackProgress: Double = 0
    private var tileRegionProgress: Double = 0
    private var styleDone = false
    private var tilesDone = false

    // ── PREFETCH (kaydırmada kasma yok) ──
    private let cellDeg = 0.09                                  // grid hücresi (~10 km) — kaydırma payı bol
    private let prefetchZoom: ClosedRange<UInt8> = 12...16      // oyun zoom'u; alt bandı kırpınca hızlı+küçük
    private var cachedCells: [String] = []                     // LRU sırası (son = en yeni)
    private var inFlight = Set<String>()
    private let maxCells = 20                                   // ~disk sınırı (eski hücreler silinir)

    /// İlk açılış: bulunulan geniş bölgeyi indir + çevresini prefetch et.
    func ensureOffline(center: CLLocationCoordinate2D,
                       radiusDegrees: Double = 0.10,            // GENİŞ ilk bölge (şehir + çevre)
                       zoomRange: ClosedRange<UInt8> = 0...16) {
        var radiusDegrees = radiusDegrees
        var zoomRange = zoomRange
        if Demo.active {
            regionId = String(format: "demo-v2-%.3f-%.3f", center.latitude, center.longitude)
            radiusDegrees = 0.032
            zoomRange = 14...17
        }
        tileStore.allTileRegions { [weak self] result in
            guard let self else { return }
            if case let .success(regions) = result,
               regions.contains(where: { $0.id == self.regionId }) {
                Task { @MainActor in self.status = .ready }
            } else {
                Task { @MainActor in
                    self.status = .downloading(0)
                    self.startStylePack()
                    self.loadRegion(id: self.regionId, center: center, radiusDegrees: radiusDegrees,
                                    zoomRange: zoomRange, silent: false)
                }
            }
        }
        if !Demo.active { prefetch(center: center) }            // çevre hücrelerini de önden indir
    }

    /// Harita her durduğunda çağrılır: merkez hücresi + 8 komşusu arka planda iner.
    /// Kullanıcı hangi yöne kaydırırsa kaydırsın tile hazır → gram kasma olmaz.
    func prefetch(center: CLLocationCoordinate2D) {
        guard !Demo.active else { return }
        let cx = (center.latitude / cellDeg).rounded()
        let cy = (center.longitude / cellDeg).rounded()
        for dx in -1...1 {
            for dy in -1...1 {
                downloadCell(lat: (cx + Double(dx)) * cellDeg, lng: (cy + Double(dy)) * cellDeg)
            }
        }
    }

    private func downloadCell(lat: Double, lng: Double) {
        let id = String(format: "cell-%.2f-%.2f", lat, lng)
        if inFlight.contains(id) { return }
        if let idx = cachedCells.firstIndex(of: id) {           // zaten var → LRU tazele, tekrar indirme
            cachedCells.remove(at: idx); cachedCells.append(id); return
        }
        inFlight.insert(id)
        loadRegion(id: id, center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                   radiusDegrees: cellDeg * 0.62, zoomRange: prefetchZoom, silent: true) { [weak self] ok in
            guard let self else { return }
            self.inFlight.remove(id)
            if ok { self.cachedCells.append(id); self.evict() }
        }
    }

    private func evict() {
        while cachedCells.count > maxCells {
            let old = cachedCells.removeFirst()
            tileStore.removeTileRegion(forId: old)              // en eski hücreyi diskten sil (LRU)
        }
    }

    // 1) Stil paketi (glyph/sprite/stil JSON) — offline render için şart. Bir kez iner, tüm hücrelere yeter.
    private func startStylePack() {
        let options = StylePackLoadOptions(
            glyphsRasterizationMode: .ideographsRasterizedLocally,
            metadata: ["name": regionId],
            acceptExpired: true
        )!
        offlineManager.loadStylePack(for: styleURI, loadOptions: options) { [weak self] progress in
            Task { @MainActor in
                self?.stylePackProgress = progress.completedResourceCount > 0
                    ? Double(progress.completedResourceCount) / Double(max(progress.requiredResourceCount, 1))
                    : 0
                self?.recompute()
            }
        } completion: { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success: self?.styleDone = true; self?.stylePackProgress = 1
                case .failure(let e): self?.status = .failed("StylePack: \(e.localizedDescription)")
                }
                self?.recompute()
            }
        }
    }

    // 2) Uydu döşemeleri — parametrik: id + silent (prefetch sessiz, ilk açılış status'lu) + done callback.
    private func loadRegion(id: String, center: CLLocationCoordinate2D, radiusDegrees d: Double,
                            zoomRange: ClosedRange<UInt8>, silent: Bool, done: ((Bool) -> Void)? = nil) {
        let descriptorOptions = TilesetDescriptorOptions(styleURI: styleURI, zoomRange: zoomRange, tilesets: [])
        let descriptor = offlineManager.createTilesetDescriptor(for: descriptorOptions)
        let ring = [
            CLLocationCoordinate2D(latitude: center.latitude - d, longitude: center.longitude - d),
            CLLocationCoordinate2D(latitude: center.latitude - d, longitude: center.longitude + d),
            CLLocationCoordinate2D(latitude: center.latitude + d, longitude: center.longitude + d),
            CLLocationCoordinate2D(latitude: center.latitude + d, longitude: center.longitude - d),
            CLLocationCoordinate2D(latitude: center.latitude - d, longitude: center.longitude - d),
        ]
        let geometry = Geometry.polygon(Polygon([ring]))
        guard let loadOptions = TileRegionLoadOptions(
            geometry: geometry, descriptors: [descriptor],
            metadata: ["name": id], acceptExpired: true, networkRestriction: .none
        ) else {
            if !silent { status = .failed("TileRegionLoadOptions oluşturulamadı") }
            done?(false); return
        }
        tileStore.loadTileRegion(forId: id, loadOptions: loadOptions) { [weak self] progress in
            guard !silent else { return }
            Task { @MainActor in
                self?.tileRegionProgress = Double(progress.completedResourceCount) / Double(max(progress.requiredResourceCount, 1))
                self?.recompute()
            }
        } completion: { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    if !silent { self?.tilesDone = true; self?.tileRegionProgress = 1 }
                    done?(true)
                case .failure(let e):
                    if !silent { self?.status = .failed("TileRegion: \(e.localizedDescription)") }
                    done?(false)
                }
                if !silent { self?.recompute() }
            }
        }
    }

    private func recompute() {
        if case .failed = status { return }
        if styleDone && tilesDone { status = .ready; return }
        let combined = (stylePackProgress + tileRegionProgress) / 2
        status = .downloading(min(0.99, combined))
    }
}
