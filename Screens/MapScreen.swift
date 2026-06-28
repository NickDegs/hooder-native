import SwiftUI
import CoreLocation

// ── Harita ekranı: offline uydu + canlı mülk pin'leri + yoğunlukta liste ──────
struct MapScreen: View {
    var game: GameState
    var feed: PropertyFeed
    var onSelect: (Property) -> Void

    private let start = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
    @State private var downloader = OfflineTileDownloader()
    @State private var currentCenter = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
    @State private var showAreaList = false
    @State private var listDismissed = false

    // Merkeze yakın mülkler (yoğun bölge listesi için), değere göre
    private var nearby: [Property] {
        feed.all
            .sorted { distSq($0) < distSq($1) }
            .prefix(80)
            .sorted { $0.price > $1.price }
    }

    var body: some View {
        ZStack(alignment: .top) {
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
                onDense: { dense in
                    if dense {
                        if !showAreaList && !listDismissed { withAnimation(Motion.smooth) { showAreaList = true } }
                    } else {
                        listDismissed = false
                    }
                }
            )
            .ignoresSafeArea()

            if case .downloading(let p) = downloader.status {
                Label("Harita indiriliyor… \(Int(p*100))%", systemImage: "arrow.down.circle")
                    .font(.captionB).foregroundStyle(Theme.text)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .liquidGlass(cornerRadius: 99, interactive: false)
                    .padding(.top, 150)
                    .transition(.opacity)
            }
        }
        .onAppear {
            downloader.ensureOffline(center: start)
            Task {
                let added = await PropertyService.shared.fetchArea(lat: start.latitude, lng: start.longitude)
                if !added.isEmpty { await MainActor.run { feed.ingest(added) } }
            }
        }
        .sheet(isPresented: $showAreaList, onDismiss: { listDismissed = true }) {
            AreaListSheet(game: game, properties: nearby, onSelect: { p in
                showAreaList = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSelect(p) }
            })
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
        }
        .animation(Motion.smooth, value: downloaderProgress)
    }

    private func distSq(_ p: Property) -> Double {
        let dx = p.lat - currentCenter.latitude, dy = p.lng - currentCenter.longitude
        return dx*dx + dy*dy
    }

    private var downloaderProgress: Double {
        if case .downloading(let p) = downloader.status { return p }
        return downloader.status == .ready ? 1 : 0
    }
}
