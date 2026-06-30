import Foundation
import CoreLocation

// ── Gerçek mülk servisi (Mapbox tilequery + reverse geocode) ──────────────────
// Tüm dünyada, baktığın koordinatın çevresindeki GERÇEK POI'leri (otel/ofis/mağaza/
// landmark) ve binaları çeker → satın alınabilir Property'ye çevirir. Aynı bölge
// tekrar çekilmez (cache). PWA'daki localProperties.ts mantığının native karşılığı.
actor PropertyService {
    static let shared = PropertyService()

    private var registry: [String: Property] = [:]
    private var fetchedAreas: [(lat: Double, lng: Double)] = []
    private var hydrated = false
    private let regKey = "hooder_props_v1", areaKey = "hooder_areas_v1"

    private var token: String {
        Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String ?? ""
    }

    // ── Kalıcı cache: bir kez indirilen mülkler diske kaydedilir → açılışta/revisit'te
    //    etiketler ANINDA görünür (yeni tilequery yok). Canlı bilgi tıklayınca (detay) gelir.
    private func hydrate() {
        guard !hydrated else { return }
        hydrated = true
        let d = UserDefaults.standard
        if let data = d.data(forKey: regKey), let arr = try? JSONDecoder().decode([Property].self, from: data) {
            for p in arr { registry[p.id] = p }
        }
        if let a = d.array(forKey: areaKey) as? [[Double]] {
            for x in a where x.count == 2 { fetchedAreas.append((x[0], x[1])) }
        }
    }
    private func persist() {
        let d = UserDefaults.standard
        // KALICI cache: 20.000 mülke kadar diskte tut → bir kez indirilen bölge sonsuza dek anında.
        let arr = Array(Array(registry.values).suffix(20000))
        if let data = try? JSONEncoder().encode(arr) { d.set(data, forKey: regKey) }
        d.set(fetchedAreas.suffix(4000).map { [$0.lat, $0.lng] }, forKey: areaKey)
    }

    /// Açılışta haritaya ANINDA basmak için diskteki tüm cache'li mülkler.
    func cachedProperties() -> [Property] { hydrate(); return Array(registry.values) }

    // Kategori eşlemesi (POI class → oyun kategorisi + temel fiyat + prestij)
    private static let classMap: [String: (cat: PropertyCategory, base: Double, prestige: Int)] = [
        "lodging": (.hotel, 90_000_000, 5), "commercial": (.retail, 28_000_000, 3),
        "food_and_drink": (.retail, 14_000_000, 2), "store_like": (.retail, 20_000_000, 3),
        "office": (.office, 65_000_000, 4), "landmark": (.landmark, 160_000_000, 5),
        "historic": (.landmark, 140_000_000, 5), "museum": (.landmark, 120_000_000, 5),
        "park_like": (.park, 18_000_000, 2), "sport_and_leisure": (.stadium, 110_000_000, 4),
        "education": (.building, 45_000_000, 3), "medical": (.building, 55_000_000, 3),
        "general": (.building, 30_000_000, 2),
    ]

    func allRegistered() -> [Property] { Array(registry.values) }

    // ── Yer arama (forward geocode) — herhangi bir şehir/ülke/semt → koordinat ────
    func geocode(_ query: String) async -> (coord: CLLocationCoordinate2D, place: String)? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty, q.count >= 2,
              let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        guard let url = URL(string: "https://api.mapbox.com/geocoding/v5/mapbox.places/\(enc).json?types=place,locality,neighborhood,district,region,country,address&limit=5&language=\(lang)&access_token=\(token)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let geo = try JSONDecoder().decode(FwdGeo.self, from: data)
            // Şehir/semt seviyesini ülke/bölgeye tercih et (ör. "Roma" → şehir, ülke değil)
            let cityTypes: Set<String> = ["address","neighborhood","locality","place","district"]
            let f = geo.features.first { !Set($0.place_type).isDisjoint(with: cityTypes) } ?? geo.features.first
            guard let f, f.center.count >= 2 else { return nil }
            return (CLLocationCoordinate2D(latitude: f.center[1], longitude: f.center[0]), f.place_name)
        } catch { return nil }
    }

    private func alreadyFetched(_ lat: Double, _ lng: Double) -> Bool {
        fetchedAreas.contains { hypot($0.lat - lat, $0.lng - lng) < 0.0035 } // ~350 m
    }

    /// Koordinatın çevresindeki gerçek mülkleri çek (yeni eklenenleri döndürür).
    @discardableResult
    func fetchArea(lat: Double, lng: Double) async -> [Property] {
        hydrate()
        guard !token.isEmpty, !alreadyFetched(lat, lng) else { return [] }
        fetchedAreas.append((lat, lng))
        if fetchedAreas.count > 4000 { fetchedAreas.removeFirst(fetchedAreas.count - 4000) }

        async let ctx = reverseGeocode(lat: lat, lng: lng)
        async let feats = tilequery(lat: lat, lng: lng)
        let area = await ctx
        let features = await feats

        var added: [Property] = []
        for f in features {
            guard let p = convert(f, area: area) else { continue }
            if registry[p.id] == nil { registry[p.id] = p; added.append(p) }
        }
        if !added.isEmpty { persist() }   // yeni indirilenleri diske kaydet (kalıcı cache)
        return added
    }

    /// ÖNDEN YÜKLEME: merkez + 4 komşu bölgeyi paralel indir → kullanıcı kaydırınca/
    /// yaklaşınca veri ZATEN hazır = etiketler anında. İndirilmiş komşular atlanır
    /// (alreadyFetched), yani sadece yeni sınır indirilir → ağ israfı yok, kalıcı cache.
    @discardableResult
    func prefetchArea(lat: Double, lng: Double) async -> [Property] {
        hydrate()
        let off = 0.0075   // ~800 m komşu offset (tilequery 1000 m yarıçapıyla örtüşür)
        let pts = [(lat, lng), (lat + off, lng), (lat - off, lng), (lat, lng + off), (lat, lng - off)]
        var all: [Property] = []
        await withTaskGroup(of: [Property].self) { group in
            for (la, ln) in pts { group.addTask { await self.fetchArea(lat: la, lng: ln) } }
            for await r in group { all += r }
        }
        return all
    }

    // ── Tilequery (POI + bina) ────────────────────────────────────────────────
    private func tilequery(lat: Double, lng: Double) async -> [TileFeature] {
        guard lat.isFinite, lng.isFinite,
              let url = URL(string: "https://api.mapbox.com/v4/mapbox.mapbox-streets-v8/tilequery/\(lng),\(lat).json?radius=1000&limit=50&dedupe=true&layers=poi_label,building&access_token=\(token)") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(TileResponse.self, from: data).features
        } catch { return [] }
    }

    // ── Reverse geocode (semt/şehir/ülke) ─────────────────────────────────────
    private func reverseGeocode(lat: Double, lng: Double) async -> AreaContext {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        guard lat.isFinite, lng.isFinite,
              let url = URL(string: "https://api.mapbox.com/geocoding/v5/mapbox.places/\(lng),\(lat).json?types=country,region,district,place,locality,neighborhood&language=\(lang)&access_token=\(token)") else {
            return AreaContext(district: "Çevre", city: "Bölge", country: "")
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let geo = try JSONDecoder().decode(GeoResponse.self, from: data)
            func pick(_ t: String) -> String? { geo.features.first { $0.place_type.contains(t) }?.text }
            return AreaContext(
                district: pick("neighborhood") ?? pick("locality") ?? pick("district") ?? "Çevre",
                city: pick("place") ?? pick("district") ?? pick("region") ?? "Bölge",
                country: (geo.features.first { $0.place_type.contains("country") }?.properties?.short_code ?? "").uppercased()
            )
        } catch { return AreaContext(district: "Çevre", city: "Bölge", country: "") }
    }

    // ── Feature → Property ────────────────────────────────────────────────────
    private func convert(_ f: TileFeature, area: AreaContext) -> Property? {
        guard let coords = f.geometry?.coordinates, coords.count >= 2 else { return nil }
        let lng = coords[0], lat = coords[1]
        let isBuilding = f.properties?.tilequery?.layer == "building"
        let name = f.properties?.name_en ?? f.properties?.name
        let seed = hash01("\(name ?? "b"):\(lat):\(lng)")

        if isBuilding {
            let height = f.properties?.height ?? 0
            let kind = height > 60 ? "Rezidans" : height > 25 ? "Plaza" : "Apartman"
            let cat: PropertyCategory = height > 25 ? .office : .building
            let base = height > 60 ? 28_000_000.0 : height > 25 ? 22_000_000 : 7_000_000
            let price = max(2_000_000, (base * (0.6 + seed * 1.6) / 100_000).rounded() * 100_000)
            return Property(
                id: "bld_\(String(format: "%.5f", lat))_\(String(format: "%.5f", lng))",
                name: "\(area.district) \(kind) No.\(Int(seed * 90) + 1)",
                neighborhood: area.district, city: area.city, category: cat,
                price: price, incomePerDay: max(1500, (price * 0.0009).rounded()),
                prestige: cat == .office ? 3 : 1, lat: lat, lng: lng)
        } else {
            guard let name, !name.isEmpty else { return nil }
            let cls = f.properties?.class ?? "general"
            let meta = Self.classMap[cls] ?? Self.classMap["general"]!
            let price = (meta.base * (0.55 + seed * 1.7) / 100_000).rounded() * 100_000
            return Property(
                id: "loc_\(String(format: "%.5f", lat))_\(String(format: "%.5f", lng))_\(cls)",
                name: name, neighborhood: area.district, city: area.city, category: meta.cat,
                price: price, incomePerDay: max(1000, (price * 0.0009).rounded()),
                prestige: min(5, meta.prestige + (seed > 0.8 ? 1 : 0)), lat: lat, lng: lng)
        }
    }

    private func hash01(_ s: String) -> Double {
        var h: UInt32 = 2166136261
        for b in s.utf8 { h ^= UInt32(b); h = h &* 16777619 }
        return Double(h) / Double(UInt32.max)
    }
}

// ── Çözümleme modelleri ───────────────────────────────────────────────────────
struct AreaContext { let district: String; let city: String; let country: String }

private struct TileResponse: Decodable { let features: [TileFeature] }
struct TileFeature: Decodable {
    let geometry: Geom?
    let properties: Props?
    struct Geom: Decodable { let coordinates: [Double]? }
    struct Props: Decodable {
        let name: String?; let name_en: String?; let `class`: String?
        let height: Double?; let tilequery: TQ?
        struct TQ: Decodable { let layer: String? }
    }
}
private struct GeoResponse: Decodable { let features: [GeoFeature] }
private struct GeoFeature: Decodable {
    let text: String; let place_type: [String]; let properties: GP?
    struct GP: Decodable { let short_code: String? }
}
// Forward geocode (yer arama) yanıtı
private struct FwdGeo: Decodable { let features: [FwdFeat] }
private struct FwdFeat: Decodable { let place_name: String; let place_type: [String]; let center: [Double] }
