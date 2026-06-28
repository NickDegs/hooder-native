import Foundation
import Observation
import MapboxMaps
import CoreLocation

// ── Otomatik offline döşeme indirici ──────────────────────────────────────────
// Uygulama ilk açıldığında, gösterilecek bölgenin UYDU döşemelerini + stil paketini
// (StylePack) otomatik, arka planda indirir ve cihazda saklar (TileStore + OfflineManager).
// İndirme bitince harita İNTERNETSİZ (uçak modu) açılır — döşemeler diskten gelir.
// Kullanıcı hiçbir şeye basmaz; her şey kendiliğinden olur.
//
// Mapbox Maps SDK v11 API (mapbox-maps-ios, from: 11.0.0).
@MainActor
@Observable
final class OfflineTileDownloader {

    enum Status: Equatable {
        case idle
        case downloading(Double)   // 0...1 (stil + döşeme birleşik ilerleme)
        case ready                 // tamamen offline kullanılabilir
        case failed(String)
    }

    private(set) var status: Status = .idle

    private let tileStore = TileStore.default
    private let offlineManager = OfflineManager()

    // Bu bölge için tekil kimlikler
    private let regionId = "home-region"
    private let styleURI: StyleURI = .satelliteStreets

    // İlerleme takibi (stil + döşeme ayrı gelir, birleştirip tek yüzde veririz)
    private var stylePackProgress: Double = 0
    private var tileRegionProgress: Double = 0
    private var styleDone = false
    private var tilesDone = false

    /// Merkez koordinat etrafında bir bölgeyi (bbox) offline indirir.
    /// - Parameters:
    ///   - center: Sabit merkez (GPS sorulmaz).
    ///   - radiusDegrees: Bölge yarıçapı (derece). ~0.06 ≈ şehir ölçeği.
    ///   - zoomRange: İndirilecek zoom aralığı. Yüksek üst sınır = daha çok disk.
    func ensureOffline(center: CLLocationCoordinate2D,
                       radiusDegrees: Double = 0.06,
                       zoomRange: ClosedRange<UInt8> = 0...16) {
        // Zaten indirildiyse (önceki açılış) tekrar indirme — diskten hazır.
        tileStore.allTileRegions { [weak self] result in
            guard let self else { return }
            if case let .success(regions) = result,
               regions.contains(where: { $0.id == self.regionId }) {
                Task { @MainActor in self.status = .ready }
            } else {
                Task { @MainActor in
                    self.status = .downloading(0)
                    self.startStylePack()
                    self.startTileRegion(center: center, radiusDegrees: radiusDegrees, zoomRange: zoomRange)
                }
            }
        }
    }

    // 1) Stil paketi (glyph/sprite/stil JSON) — offline render için şart
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

    // 2) Uydu döşemeleri (raster) — bölge poligonu için
    private func startTileRegion(center: CLLocationCoordinate2D,
                                 radiusDegrees d: Double,
                                 zoomRange: ClosedRange<UInt8>) {
        let descriptorOptions = TilesetDescriptorOptions(styleURI: styleURI, zoomRange: zoomRange, tilesets: [])
        let descriptor = offlineManager.createTilesetDescriptor(for: descriptorOptions)

        // Merkez etrafında bbox poligon (kapalı halka)
        let ring = [
            CLLocationCoordinate2D(latitude: center.latitude - d, longitude: center.longitude - d),
            CLLocationCoordinate2D(latitude: center.latitude - d, longitude: center.longitude + d),
            CLLocationCoordinate2D(latitude: center.latitude + d, longitude: center.longitude + d),
            CLLocationCoordinate2D(latitude: center.latitude + d, longitude: center.longitude - d),
            CLLocationCoordinate2D(latitude: center.latitude - d, longitude: center.longitude - d),
        ]
        let geometry = Geometry.polygon(Polygon([ring]))

        guard let loadOptions = TileRegionLoadOptions(
            geometry: geometry,
            descriptors: [descriptor],
            metadata: ["name": regionId],
            acceptExpired: true,
            networkRestriction: .none
        ) else {
            status = .failed("TileRegionLoadOptions oluşturulamadı")
            return
        }

        tileStore.loadTileRegion(forId: regionId, loadOptions: loadOptions) { [weak self] progress in
            Task { @MainActor in
                self?.tileRegionProgress = Double(progress.completedResourceCount) / Double(max(progress.requiredResourceCount, 1))
                self?.recompute()
            }
        } completion: { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success: self?.tilesDone = true; self?.tileRegionProgress = 1
                case .failure(let e): self?.status = .failed("TileRegion: \(e.localizedDescription)")
                }
                self?.recompute()
            }
        }
    }

    // Stil + döşeme ilerlemesini birleştir; ikisi de bitince .ready
    private func recompute() {
        if case .failed = status { return }
        if styleDone && tilesDone {
            status = .ready
            return
        }
        let combined = (stylePackProgress + tileRegionProgress) / 2
        status = .downloading(min(0.99, combined))
    }
}
