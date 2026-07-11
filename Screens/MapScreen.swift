import SwiftUI
import CoreLocation

// ── Harita ekranı: offline uydu + canlı mülk pin'leri + "konumuma git" ────────
struct MapScreen: View {
    var game: GameState
    var feed: PropertyFeed
    var onSelect: (Property) -> Void
    var externalFly: CLLocationCoordinate2D? = nil   // tanıtım turu: dışarıdan kamera hedefi
    var cinematicOrbit: Bool = false                 // tanıtım: tile'lar hazır olunca sürekli orbit

    // Tanıtım turunda -demoLat/-demoLng ile verilen şehirde başla (yoksa Manhattan)
    private let start = Demo.active ? (Demo.cityCenter ?? Demo.newYork)
                                    : CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
    @State private var downloader = OfflineTileDownloader()
    @State private var location = LocationManager()
    @State private var currentCenter = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
    @State private var flyTarget: CLLocationCoordinate2D?
    @State private var locating = false
    @State private var search = ""
    @State private var searching = false
    @State private var searchMsg: String?
    @State private var showAreaList = false
    @State private var cityProgress: Double = 1      // <1 iken "şehir iniyor" rozeti
    @State private var lastCityLoad: CLLocationCoordinate2D?

    // Bir koordinattaki ŞEHRİ komple indir (ilerleme + harita dolarak)
    private func loadCity(_ c: CLLocationCoordinate2D) {
        // Aynı bölgede dönerken boşa tetikleme: son indirmeden ~2.5 km içindeyse atla
        if let l = lastCityLoad, abs(l.latitude - c.latitude) < 0.022, abs(l.longitude - c.longitude) < 0.022 { return }
        lastCityLoad = c
        let f = feed
        Task {
            await PropertyService.shared.downloadCity(lat: c.latitude, lng: c.longitude) { chunk, p in
                Task { @MainActor in
                    if !chunk.isEmpty { f.ingest(chunk) }
                    cityProgress = p
                }
            }
        }
    }

    // Bulunduğun bölgenin mülkleri (merkeze yakın), değere göre — Liste butonu için
    private var nearby: [Property] {
        feed.all.sorted { distSq($0) < distSq($1) }.prefix(80).sorted { $0.price > $1.price }
    }
    private func distSq(_ p: Property) -> Double {
        let dx = p.lat - currentCenter.latitude, dy = p.lng - currentCenter.longitude
        return dx*dx + dy*dy
    }

    var body: some View {
        ZStack(alignment: .top) {
            PropertyMapView(
                center: start, zoom: Demo.active ? 14.4 : 13.5,
                properties: feed.all, ownedIds: game.ownedIds,
                onSelect: onSelect,
                onRegionChange: { c in
                    currentCenter = c
                    loadCity(c)   // bulunduğun şehri komple indir (zaten inmişse anında)
                },
                flyTarget: flyTarget,
                cinematic: Demo.active,
                cinematicOrbit: cinematicOrbit
            )
            .ignoresSafeArea()

            // Üst: yer arama çubuğu + indirme rozeti
            VStack(spacing: 8) {
                // 🔎 Yer ara (şehir/ülke/semt) → oraya uç + mülkleri yükle
                HStack(spacing: 8) {
                    if searching { ProgressView().tint(.white).scaleEffect(0.8) }
                    else { Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted) }
                    TextField(L10n.shared.t("search_place"), text: $search)
                        .foregroundStyle(Theme.text).font(.bodyB)
                        .submitLabel(.search)
                        .onSubmit { runSearch() }
                    if !search.isEmpty {
                        Button { search = ""; searchMsg = nil } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .liquidGlass(cornerRadius: Theme.rMd, interactive: false)
                .padding(.horizontal, 14)

                if let searchMsg {
                    Text(searchMsg).font(.captionB).foregroundStyle(Theme.textSub)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .liquidGlass(cornerRadius: 99, interactive: false)
                }
                if case .downloading(let p) = downloader.status, !Demo.active {   // demoda rozet gizli (temiz çekim)
                    Label("\(L10n.shared.t("map_downloading"))… \(Int(p*100))%", systemImage: "arrow.down.circle")
                        .font(.captionB).foregroundStyle(Theme.text)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .liquidGlass(cornerRadius: 99, interactive: false)
                }
                if cityProgress < 1, !Demo.active {   // demoda rozet gizli (temiz çekim)
                    Label("\(L10n.shared.t("city_downloading"))… \(Int(cityProgress*100))%", systemImage: "building.2.fill")
                        .font(.captionB).foregroundStyle(Theme.text)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .liquidGlass(cornerRadius: 99, interactive: false)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 132)   // HUD çubuğunun altına gelsin (çakışma yok)
        }
        // ── Sol alt: bulunduğun bölgenin LİSTESİ ──────────────────────────────
        .overlay(alignment: .bottomLeading) {
            Button { showAreaList = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                    Text(L10n.shared.t("list")).font(.bodyB)
                }
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 16).frame(height: 52)
                .liquidGlass(cornerRadius: 99)
            }
            .buttonStyle(.plain)
            .padding(.leading, 16).padding(.bottom, 118)
        }
        // ── Sağ alt: konumuma git ─────────────────────────────────────────────
        .overlay(alignment: .bottomTrailing) {
            Button {
                locating = true
                location.requestAndLocate()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 52, height: 52)
                    .liquidGlass(cornerRadius: 99)
                    .opacity(locating ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16).padding(.bottom, 118)
        }
        .sheet(isPresented: $showAreaList) {
            AreaListSheet(game: game, properties: nearby, onSelect: { p in
                showAreaList = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSelect(p) }
            })
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
        }
        .onAppear {
            // Offline tile indir (HEM normal HEM demo): CI simülatöründe online streaming render
            // OLMUYOR (harita siyah) ama TileStore indirmesi çalışıyor (screenshot'lar böyle dolu).
            // Manhattan turunun 3 durağı da 0.06° (~6.6km) bölgenin içinde → tur boyunca dolu kalır.
            downloader.ensureOffline(center: start)
            // Diskteki cache'li mülkleri ANINDA bas (etiketler önceden indirilmiş gibi gelir)
            Task {
                let cached = await PropertyService.shared.cachedProperties()
                if !cached.isEmpty { await MainActor.run { feed.ingest(cached) } }
            }
            location.onFix = { c in
                locating = false
                flyTarget = c
                currentCenter = c
                loadCity(c)   // konumundaki şehri komple indir
            }
            loadCity(start)   // açılışta bulunduğun şehri komple indir
        }
        // Tanıtım turu: dışarıdan gelen kamera hedefine uç + o şehrin mülklerini indir
        .onChange(of: externalFly.map { "\($0.latitude),\($0.longitude)" }) { _, _ in
            if let t = externalFly { flyTarget = t; currentCenter = t; loadCity(t) }
        }
        .animation(Motion.smooth, value: downloaderProgress)
    }

    // Yer ara → koordinat bul → oraya uç + o bölgenin mülklerini yükle
    private func runSearch() {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return }
        searching = true; searchMsg = nil
        Task {
            let hit = await PropertyService.shared.geocode(q)
            await MainActor.run { searching = false }
            guard let hit else { await MainActor.run { searchMsg = "\"\(q)\" bulunamadı" }; return }
            await MainActor.run {
                flyTarget = hit.coord
                currentCenter = hit.coord
                searchMsg = "📍 \(hit.place)"
            }
            await MainActor.run { loadCity(hit.coord) }   // aranan şehri komple indir
        }
    }

    private var downloaderProgress: Double {
        if case .downloading(let p) = downloader.status { return p }
        return downloader.status == .ready ? 1 : 0
    }
}
