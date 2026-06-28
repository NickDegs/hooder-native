import SwiftUI
import MapboxMaps
import CoreLocation

// ── Uydu harita + canlı mülk pin'leri (UIViewRepresentable) ───────────────────
// Arka plan = OFFLINE uydu (.satelliteStreets). Üstte = CANLI mülk pin'leri.
// • GPS sorulmaz (puck yok, sabit merkez).
// • DECLUTTER + CAP: ekran merkezine yakın mülkler önce, piksel-aralıkla üst üste
//   binmesin, en fazla `cap` marker. YOĞUN bölgede (inView > dense) marker ÇİZİLMEZ
//   → onDense(true) → App liste açar (kasma yok, harita dokunulabilir).
// • Pin tap → onSelect(property).
struct PropertyMapView: UIViewRepresentable {

    let center: CLLocationCoordinate2D
    let zoom: CGFloat
    let properties: [Property]
    let ownedIds: Set<String>
    let onSelect: (Property) -> Void
    var onRegionChange: ((CLLocationCoordinate2D) -> Void)? = nil
    var onDense: ((Bool) -> Void)? = nil
    var flyTarget: CLLocationCoordinate2D? = nil   // "konumuma git" → buraya uç

    // Aynı anda en fazla marker + üst üste binme piksel aralığı
    private let cap = 30
    private let gapX: CGFloat = 78
    private let gapY: CGFloat = 42
    private let denseLimit = 60

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MapView {
        let cam = CameraOptions(center: center, zoom: zoom, pitch: 52)
        let opts = MapInitOptions(cameraOptions: cam, styleURI: .satelliteStreets)
        let map = MapView(frame: .zero, mapInitOptions: opts)
        map.location.options.puckType = nil
        map.ornaments.options.scaleBar.visibility = .hidden

        let manager = map.annotations.makePointAnnotationManager()
        manager.iconAllowOverlap = true
        manager.textAllowOverlap = true

        let c = context.coordinator
        c.map = map
        c.manager = manager

        map.mapboxMap.onStyleLoaded.observeNext { _ in
            c.reapply()
            // İlk layout/boyut otursun diye birkaç kez tekrar dene (marker boş kalmasın)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { c.reapply() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { c.reapply() }
        }.store(in: &c.cancelables)

        // Kamera durunca: bölge verisi + marker yeniden cap/declutter
        map.mapboxMap.onMapIdle.observe { [weak map] _ in
            guard let center = map?.mapboxMap.cameraState.center else { return }
            c.parent.onRegionChange?(center)
            c.reapply()
        }.store(in: &c.cancelables)

        return map
    }

    func updateUIView(_ uiView: MapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.reapply()
        // "Konumuma git" hedefi değiştiyse oraya uç
        if let t = flyTarget, context.coordinator.lastFly?.latitude != t.latitude || context.coordinator.lastFly?.longitude != t.longitude {
            context.coordinator.lastFly = t
            uiView.camera.fly(to: CameraOptions(center: t, zoom: 14, pitch: 52), duration: 1.2)
        }
    }

    // ── Coordinator ───────────────────────────────────────────────────────────
    final class Coordinator {
        var parent: PropertyMapView
        weak var map: MapView?
        var manager: PointAnnotationManager?
        var cancelables = Set<AnyCancelable>()
        var lastFly: CLLocationCoordinate2D?
        private var index: [String: Property] = [:]

        init(_ parent: PropertyMapView) { self.parent = parent }

        func reapply() {
            guard let map, let manager else { return }
            let props = parent.properties
            let owned = parent.ownedIds
            index = Dictionary(props.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

            let size = map.bounds.size
            guard size.width > 0 else { manager.annotations = []; return }
            let cx = size.width / 2, cy = size.height / 2
            let margin: CGFloat = 40

            // Ekranda görünenleri projekte et + merkeze uzaklık
            struct Cand { let p: Property; let pt: CGPoint; let d: CGFloat }
            var cands: [Cand] = []
            for p in props {
                let pt = map.mapboxMap.point(for: p.coordinate)
                guard pt.x >= -margin, pt.x <= size.width + margin,
                      pt.y >= -margin, pt.y <= size.height + margin else { continue }
                cands.append(Cand(p: p, pt: pt, d: hypot(pt.x - cx, pt.y - cy)))
            }

            // Yoğunluk bilgisini bildir AMA marker'ları HER ZAMAN çiz (etiketler görünsün).
            parent.onDense?(cands.count > parent.denseLimit)

            // Merkeze yakın olan önce + piksel-aralıkla declutter + cap
            cands.sort { $0.d < $1.d }
            var placed: [CGPoint] = []
            var chosen: [Property] = []
            for c in cands {
                if placed.contains(where: { abs($0.x - c.pt.x) < parent.gapX && abs($0.y - c.pt.y) < parent.gapY }) { continue }
                placed.append(c.pt); chosen.append(c.p)
                if chosen.count >= parent.cap { break }
            }

            manager.annotations = chosen.map { p in
                let isOwned = owned.contains(p.id)
                var ann = PointAnnotation(id: p.id, coordinate: p.coordinate)
                ann.image = .init(image: Self.pin(owned: isOwned, category: p.category),
                                  name: isOwned ? "pin-own" : "pin-\(p.category.rawValue)")
                ann.iconAnchor = .bottom
                ann.textField = "\(p.category.emoji) \(formatMoney(p.price))"
                ann.textOffset = [0, 1.0]
                ann.textColor = StyleColor(isOwned ? UIColor.systemGreen : .white)
                ann.textHaloColor = StyleColor(.black)
                ann.textHaloWidth = 1.3
                ann.textSize = 11
                ann.tapHandler = { [weak self] _ in
                    guard let self, let prop = self.index[p.id] else { return false }
                    self.parent.onSelect(prop); return true
                }
                return ann
            }
        }

        // Görsel cache: kategori×owned için tek seferlik üretim (yalnız main thread'de kullanılır)
        nonisolated(unsafe) static var imageCache: [String: UIImage] = [:]
        static func pin(owned: Bool, category: PropertyCategory) -> UIImage {
            let key = "\(owned ? "own" : category.rawValue)"
            if let cached = imageCache[key] { return cached }
            let color: UIColor = owned ? .systemGreen : {
                switch category {
                case .hotel: return .systemPurple
                case .office: return .systemBlue
                case .retail: return .systemOrange
                case .landmark: return .systemPink
                case .park: return .systemGreen
                case .stadium: return .systemTeal
                case .building: return .systemGray
                }
            }()
            let size = CGSize(width: 22, height: 22)
            let img = UIGraphicsImageRenderer(size: size).image { ctx in
                let r = CGRect(x: 3, y: 3, width: 16, height: 16)
                ctx.cgContext.setFillColor(color.withAlphaComponent(0.92).cgColor)
                ctx.cgContext.fillEllipse(in: r)
                ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
                ctx.cgContext.setLineWidth(2)
                ctx.cgContext.strokeEllipse(in: r)
            }
            imageCache[key] = img
            return img
        }
    }
}
