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
    var cinematic: Bool = false                    // tanıtım: yavaş sürekli kamera orbiti

    // Symbol layer'a verilen mülk sayısı (Mapbox off-screen cull + collision yapar; yüksek olabilir).
    private let maxMarkers = 1000

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MapView {
        let cam = CameraOptions(center: center, zoom: zoom, pitch: 52)
        let opts = MapInitOptions(cameraOptions: cam, styleURI: .satelliteStreets)
        let map = MapView(frame: .zero, mapInitOptions: opts)
        map.location.options.puckType = nil
        map.ornaments.options.scaleBar.visibility = .hidden
        map.ornaments.options.compass.visibility = .hidden   // pusula HUD arkasında kalmasın
        map.ornaments.options.logo.margins = .init(x: 8, y: 8)

        let manager = map.annotations.makePointAnnotationManager()
        // Çakışma YOK: Mapbox'ın kendi collision'ı pill'leri üst üste bindirmez ve
        // ZOOM'a göre gösterir (yaklaş→çok, uzaklaş→az/değerli). GPU'da akıcı, yanıp sönmez.
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
            // FALLBACK: 10 sn içinde idle olmazsa yine de orbit başlat (harita boş kalmasın diye)
            if self.cinematic { DispatchQueue.main.asyncAfter(deadline: .now() + 10) { c.startCinematic() } }
        }.store(in: &c.cancelables)

        // Kamera durunca: o bölgenin gerçek mülklerini yükle (yeni veri gelince set değişir → reapply).
        // Pan/zoom sırasında ETİKETLERİ MAPBOX kendisi gösterip gizler (collision) → yeniden kurmaya
        // gerek yok, bu yüzden yanıp sönmez. reapply yalnız VERİ değişince çalışır (skip'li).
        map.mapboxMap.onMapIdle.observe { [weak map] _ in
            guard let center = map?.mapboxMap.cameraState.center else { return }
            c.parent.onRegionChange?(center)
            c.reapply()
            // Orbit'i İLK idle'da başlat = uydu tile'ları İNDİKTEN sonra (siyah harita önlenir).
            // Orbit merkezi sabit tutar (yalnız bearing) → yeni tile gerekmez, aynı görüntü döner.
            if c.parent.cinematic { DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { c.startCinematic() } }
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
        var lastReapply: Double = 0
        private var index: [String: Property] = [:]

        // ── Sinematik orbit (tanıtım): yavaş sürekli kamera dönüşü + hafif yaklaşma ──
        private var orbitLink: CADisplayLink?
        private var orbitBearing: Double = 0
        func startCinematic() {
            guard orbitLink == nil, let map else { return }
            orbitBearing = map.mapboxMap.cameraState.bearing
            let link = CADisplayLink(target: self, selector: #selector(orbitTick))
            link.preferredFramesPerSecond = 30
            link.add(to: .main, forMode: .common)
            orbitLink = link
        }
        @objc private func orbitTick() {
            guard let map else { return }
            // ÇOK yavaş dönüş + düşük pitch → simülatörün düşük FPS'inde bile akıcı görünür
            // (kareler arası fark minimal) ve motion-interpolation temiz çalışır.
            orbitBearing += 0.05                              // ~1.5°/sn sinematik
            let c = map.mapboxMap.cameraState
            map.mapboxMap.setCamera(to: CameraOptions(center: c.center, bearing: orbitBearing, pitch: 40))
        }

        init(_ parent: PropertyMapView) { self.parent = parent }
        deinit { orbitLink?.invalidate() }

        var lastSig = ""

        // SABİT SET: tüm mülkleri (değere göre, cap'li) symbol layer'a bir kez ver. Pan/zoom'da
        // Mapbox collision hangilerini göstereceğine kendi karar verir (yaklaş→çok, uzaklaş→az).
        // Set yalnız VERİ değişince yeniden kurulur (skip'li) → yeniden çizim yok = YANIP SÖNME YOK.
        func reapply() {
            guard let manager else { return }
            let props = parent.properties
            let owned = parent.ownedIds
            let top = props.sorted { $0.price > $1.price }.prefix(parent.maxMarkers)
            // İmza: set (id'ler) + sahiplik değişmediyse yeniden kurma
            let sig = "\(props.count)|\(owned.count)|\(top.first?.id ?? "")|\(top.last?.id ?? "")"
            guard sig != lastSig else { return }
            lastSig = sig
            index = Dictionary(top.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            manager.annotations = top.map { p in
                let isOwned = owned.contains(p.id)
                let isRival = !isOwned && Rivals.owner(of: p) != nil
                let (img, key) = Self.pill(price: formatMoney(p.price), emoji: p.category.emoji,
                                           owned: isOwned, rival: isRival, accent: Self.accent(p.category))
                var ann = PointAnnotation(id: p.id, coordinate: p.coordinate)
                ann.image = .init(image: img, name: key)
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

        // ── Kompakt cam pill (emoji + fiyat, tek satır) — yoğunlukta okunur ───────
        // Tek görsel baked → symbol layer'da ANINDA, GPU. Detay tıklayınca açılır.
        nonisolated(unsafe) static var pillCache: [String: UIImage] = [:]
        nonisolated(unsafe) static let pillLock = NSLock()        // cache thread-safe (çok thread'li erişimde çökme yok)
        static func pill(price: String, emoji: String, owned: Bool, rival: Bool, accent: UIColor) -> (img: UIImage, key: String) {
            let key = "\(owned ? "o" : rival ? "r" : "n")|\(emoji)|\(price)"
            pillLock.lock()
            if let c = pillCache[key] { pillLock.unlock(); return (c, key) }
            if pillCache.count > 1200 { pillCache.removeAll() }
            pillLock.unlock()

            let priceFont = UIFont.systemFont(ofSize: 12, weight: .heavy)
            let emojiFont = UIFont.systemFont(ofSize: 13)
            let priceColor: UIColor = owned ? .systemGreen : rival ? .systemOrange : UIColor(white: 1, alpha: 0.96)
            let priceAttr: [NSAttributedString.Key: Any] = [.font: priceFont, .foregroundColor: priceColor]
            let emojiAttr: [NSAttributedString.Key: Any] = [.font: emojiFont]

            let priceSz = (price as NSString).size(withAttributes: priceAttr)
            let emojiSz = (emoji as NSString).size(withAttributes: emojiAttr)
            let padH: CGFloat = 8, padV: CGFloat = 5, gap: CGFloat = 4
            let w = ceil(padH + emojiSz.width + gap + priceSz.width + padH)
            let h = ceil(padV + max(emojiSz.height, priceSz.height) + padV)
            let size = CGSize(width: w, height: h)

            let fmt = UIGraphicsImageRendererFormat(); fmt.opaque = false; fmt.scale = UIScreen.main.scale
            let img = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
                let cg = ctx.cgContext
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
                let r: CGFloat = h / 2                          // tam yuvarlak uçlar (kapsül)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: r)
                // Liquid glass: dikey gradyan (üst açık → alt koyu), yarı saydam
                cg.saveGState(); path.addClip()
                let cs = CGColorSpaceCreateDeviceRGB()
                let top = owned ? UIColor(red:0.10,green:0.28,blue:0.18,alpha:0.78) : UIColor(red:0.16,green:0.20,blue:0.32,alpha:0.74)
                let bot = owned ? UIColor(red:0.03,green:0.12,blue:0.07,alpha:0.92) : UIColor(red:0.03,green:0.05,blue:0.11,alpha:0.90)
                if let g = CGGradient(colorsSpace: cs, colors: [top.cgColor, bot.cgColor] as CFArray, locations: [0,1]) {
                    cg.drawLinearGradient(g, start: CGPoint(x:0,y:0), end: CGPoint(x:0,y:h), options: [])
                }
                // üst parıltı (cam highlight)
                let sheen = UIBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height*0.46), cornerRadius: r)
                UIColor(white: 1, alpha: 0.12).setFill(); sheen.fill()
                cg.restoreGState()
                // parlak ince kenar (specular)
                (owned ? UIColor.systemGreen.withAlphaComponent(0.85)
                       : rival ? UIColor.systemOrange.withAlphaComponent(0.8)
                       : UIColor(white:1,alpha:0.45)).setStroke()
                path.lineWidth = 1; path.stroke()
                // metin (gölgeli → her zeminde okunur)
                cg.setShadow(offset: .zero, blur: 2.5, color: UIColor.black.withAlphaComponent(0.85).cgColor)
                (emoji as NSString).draw(at: CGPoint(x: padH, y: (h - emojiSz.height)/2), withAttributes: emojiAttr)
                (price as NSString).draw(at: CGPoint(x: padH + emojiSz.width + gap, y: (h - priceSz.height)/2), withAttributes: priceAttr)
            }
            pillLock.lock(); pillCache[key] = img; pillLock.unlock()
            return (img, key)
        }
    }
}
