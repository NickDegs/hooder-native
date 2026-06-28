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

    // En değerli N mülk symbol layer'a verilir; Mapbox collision declutter eder.
    private let maxMarkers = 150

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MapView {
        let cam = CameraOptions(center: center, zoom: zoom, pitch: 52)
        let opts = MapInitOptions(cameraOptions: cam, styleURI: .satelliteStreets)
        let map = MapView(frame: .zero, mapInitOptions: opts)
        map.location.options.puckType = nil
        map.ornaments.options.scaleBar.visibility = .hidden

        let manager = map.annotations.makePointAnnotationManager()
        manager.iconAllowOverlap = true       // pin noktaları hep görünsün
        manager.textAllowOverlap = false      // fiyat metni çakışmasın (native declutter)
        manager.iconIgnorePlacement = true    // ikon yerleşimi metni engellemesin

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

        // NATIVE declutter: tüm mülkleri (değere göre en üst N) symbol layer'a ver,
        // Mapbox'ın KENDİ collision'ı (textAllowOverlap=false) çakışmayı çözer. Projeksiyon/
        // bounds hesabı YOK → ilk render'da da etiketler kesin görünür, GPU'da akıcı.
        func reapply() {
            guard let manager else { return }
            let props = parent.properties
            let owned = parent.ownedIds
            index = Dictionary(props.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

            let top = props.sorted { $0.price > $1.price }.prefix(parent.maxMarkers)
            manager.annotations = top.map { p in
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
                ann.symbolSortKey = -p.price   // değerli mülk öncelikli (collision'da üstte)
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
