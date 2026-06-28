import SwiftUI
import CoreLocation

// ── Harita ekranı: offline uydu + canlı mülk pin'leri + "konumuma git" ────────
struct MapScreen: View {
    var game: GameState
    var feed: PropertyFeed
    var onSelect: (Property) -> Void

    private let start = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
    @State private var downloader = OfflineTileDownloader()
    @State private var location = LocationManager()
    @State private var currentCenter = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
    @State private var flyTarget: CLLocationCoordinate2D?
    @State private var locating = false
    @State private var search = ""
    @State private var searching = false
    @State private var searchMsg: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PropertyMapView(
                center: start, zoom: 13.5,
                properties: feed.all, ownedIds: game.ownedIds,
                onSelect: onSelect,
                onRegionChange: { c in
                    currentCenter = c
                    Task {
                        let added = await PropertyService.shared.fetchArea(lat: c.latitude, lng: c.longitude)
                        if !added.isEmpty { await MainActor.run { feed.ingest(added) } }
                    }
                },
                flyTarget: flyTarget
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
                if case .downloading(let p) = downloader.status {
                    Label("Harita indiriliyor… \(Int(p*100))%", systemImage: "arrow.down.circle")
                        .font(.captionB).foregroundStyle(Theme.text)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .liquidGlass(cornerRadius: 99, interactive: false)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 132)   // HUD çubuğunun altına gelsin (çakışma yok)

            // 📍 Konumuma git butonu (sağ alt, tab bar'ın üstünde)
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
            .padding(.trailing, 16)
            .padding(.bottom, 100)
        }
        .onAppear {
            downloader.ensureOffline(center: start)
            location.onFix = { c in
                locating = false
                flyTarget = c
                currentCenter = c
                Task {
                    let added = await PropertyService.shared.fetchArea(lat: c.latitude, lng: c.longitude)
                    if !added.isEmpty { await MainActor.run { feed.ingest(added) } }
                }
            }
            Task {
                let added = await PropertyService.shared.fetchArea(lat: start.latitude, lng: start.longitude)
                if !added.isEmpty { await MainActor.run { feed.ingest(added) } }
            }
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
            let added = await PropertyService.shared.fetchArea(lat: hit.coord.latitude, lng: hit.coord.longitude)
            if !added.isEmpty { await MainActor.run { feed.ingest(added) } }
        }
    }

    private var downloaderProgress: Double {
        if case .downloading(let p) = downloader.status { return p }
        return downloader.status == .ready ? 1 : 0
    }
}
