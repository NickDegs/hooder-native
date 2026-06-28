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
        // Cam pill'ler üst üste binmesin → Mapbox collision declutter eder (değerli olan kazanır).
        manager.iconAllowOverlap = false
        manager.iconIgnorePlacement = false

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

            // ZOOM-BAZLI: yalnız GÖRÜNÜR coğrafi alandaki mülkler (projeksiyon değil →
            // güvenilir). Yaklaşınca alan küçülür → oradaki yerel mülkler çıkar; uzaklaşınca
            // geniş alanın en değerlileri. Böylece her zoom'da o bölgenin etiketleri görünür.
            var pool = props
            if let map {
                let cam = map.mapboxMap.cameraState
                let b = map.mapboxMap.coordinateBounds(for: CameraOptions(cameraState: cam))
                let ne = b.northeast, sw = b.southwest
                let dLat = (ne.latitude - sw.latitude) * 0.15, dLng = (ne.longitude - sw.longitude) * 0.15
                let visible = props.filter {
                    $0.lat <= ne.latitude + dLat && $0.lat >= sw.latitude - dLat &&
                    $0.lng <= ne.longitude + dLng && $0.lng >= sw.longitude - dLng
                }
                if !visible.isEmpty { pool = visible }
            }
            let top = pool.sorted { $0.price > $1.price }.prefix(parent.maxMarkers)
            manager.annotations = top.map { p in
                let isOwned = owned.contains(p.id)
                let (img, key) = Self.pill(name: p.name, price: formatMoney(p.price),
                                           emoji: p.category.emoji, owned: isOwned,
                                           accent: Self.accent(p.category))
                var ann = PointAnnotation(id: p.id, coordinate: p.coordinate)
                ann.image = .init(image: img, name: key)   // metin pill'in İÇİNDE (ayrı textField yok)
                ann.iconAnchor = .bottom
                ann.symbolSortKey = -p.price   // değerli mülk öncelikli (collision'da üstte)
                ann.tapHandler = { [weak self] _ in
                    guard let self, let prop = self.index[p.id] else { return false }
                    self.parent.onSelect(prop); return true
                }
                return ann
            }
        }

        static func accent(_ category: PropertyCategory) -> UIColor {
            switch category {
            case .hotel: return .systemPurple
            case .office: return .systemBlue
            case .retail: return .systemOrange
            case .landmark: return .systemPink
            case .park: return .systemGreen
            case .stadium: return .systemTeal
            case .building: return UIColor(white: 0.7, alpha: 1)
            }
        }

        // ── Cam pill (emoji + isim + fiyat) — eski PWA marker görünümü ────────────
        // Tek görsel olarak baked → symbol layer'da ANINDA, GPU, declutter'lı.
        nonisolated(unsafe) static var pillCache: [String: UIImage] = [:]
        static func pill(name: String, price: String, emoji: String, owned: Bool, accent: UIColor) -> (img: UIImage, key: String) {
            let shortName = name.count > 16 ? String(name.prefix(15)) + "…" : name
            let key = "\(owned ? "o" : "n")|\(shortName)|\(price)"
            if let c = pillCache[key] { return (c, key) }
            if pillCache.count > 800 { pillCache.removeAll() }   // bellek koruması

            let nameFont  = UIFont.systemFont(ofSize: 12, weight: .bold)
            let priceFont = UIFont.systemFont(ofSize: 12, weight: .heavy)
            let emojiFont = UIFont.systemFont(ofSize: 15)
            let nameAttr: [NSAttributedString.Key: Any]  = [.font: nameFont,  .foregroundColor: UIColor.white]
            let priceAttr: [NSAttributedString.Key: Any] = [.font: priceFont, .foregroundColor: owned ? UIColor.systemGreen : UIColor(white: 1, alpha: 0.95)]
            let emojiAttr: [NSAttributedString.Key: Any] = [.font: emojiFont]

            let nameSz  = (shortName as NSString).size(withAttributes: nameAttr)
            let priceSz = (price as NSString).size(withAttributes: priceAttr)
            let emojiSz = (emoji as NSString).size(withAttributes: emojiAttr)

            let padH: CGFloat = 9, padV: CGFloat = 6, gap: CGFloat = 6, lineGap: CGFloat = 1
            let textW = max(nameSz.width, priceSz.width)
            let w = ceil(padH + emojiSz.width + gap + textW + padH)
            let h = ceil(padV + nameSz.height + lineGap + priceSz.height + padV)
            let size = CGSize(width: w, height: h)

            let fmt = UIGraphicsImageRendererFormat(); fmt.opaque = false; fmt.scale = UIScreen.main.scale
            let img = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 11)
                // koyu cam zemin
                (owned ? UIColor(red: 0.05, green: 0.16, blue: 0.10, alpha: 0.90)
                       : UIColor(red: 0.05, green: 0.07, blue: 0.13, alpha: 0.88)).setFill()
                path.fill()
                // üst parıltı (cam hissi)
                let sheen = UIBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height*0.5), cornerRadius: 11)
                UIColor(white: 1, alpha: 0.06).setFill(); sheen.fill()
                // kenar (accent)
                (owned ? UIColor.systemGreen.withAlphaComponent(0.65) : accent.withAlphaComponent(0.55)).setStroke()
                path.lineWidth = 1; path.stroke()
                // emoji
                (emoji as NSString).draw(at: CGPoint(x: padH, y: (h - emojiSz.height)/2), withAttributes: emojiAttr)
                // isim + fiyat
                let tx = padH + emojiSz.width + gap
                (shortName as NSString).draw(at: CGPoint(x: tx, y: padV), withAttributes: nameAttr)
                (price as NSString).draw(at: CGPoint(x: tx, y: padV + nameSz.height + lineGap), withAttributes: priceAttr)
            }
            pillCache[key] = img
            return (img, key)
        }
    }
}
