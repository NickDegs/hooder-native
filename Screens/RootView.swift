import SwiftUI

// ── Kök kabuk: harita arka planda, üstte HUD + içerik + cam sekme çubuğu ──────
struct RootView: View {
    @State private var game = GameState()
    @State private var feed = PropertyFeed.shared
    @State private var tab: AppTab = .map
    @State private var selected: Property?

    // saniyede bir gelir tahakkuku
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            // Harita HER ZAMAN arka planda
            MapScreen(game: game, feed: feed, onSelect: { selected = $0 })
                .ignoresSafeArea()

            // Harita-dışı ekranlar: alttan kayan cam panel (yumuşak geçiş)
            if tab != .map {
                ScreenPanel(tab: tab, game: game, feed: feed, onSelect: { selected = $0 },
                            onClose: { withAnimation(Motion.smooth) { tab = .map } })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            VStack(spacing: 10) {
                HUDBar(game: game).padding(.top, 4)
                Spacer()
                GlassTabBar(tab: $tab)
            }
            .zIndex(3)
        }
        .animation(Motion.smooth, value: tab)
        .sheet(item: $selected) { p in
            PropertyDetailSheet(property: p, game: game)
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
        .onAppear { feed.start(); EconomyService.shared.start() }   // canlı ekonomi başlasın
        .task {
            // Açılışta VIP entitlement kontrolü (abonelik aktifse anında uygulanır)
            Store.shared.onVIP = { active in game.isVIP = active }
            await Store.shared.refreshVIP()
        }
        .onReceive(tick) { _ in game.tickIncome(1) }
        .preferredColorScheme(.dark)
    }
}

// Harita-dışı sekme içeriğini taşıyan cam panel — başlıktan aşağı sürükle = kapat
private struct ScreenPanel: View {
    let tab: AppTab
    var game: GameState
    var feed: PropertyFeed
    var onSelect: (Property) -> Void
    var onClose: () -> Void
    @State private var drag: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Sürükleme tutamacı + başlık (aşağı çek → kapat)
            VStack(spacing: 0) {
                Capsule().fill(.white.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)
                Text(L10n.shared.t(tab.titleKey)).font(.h3).foregroundStyle(Theme.text).padding(.vertical, 8)
                Divider().background(.white.opacity(0.08))
            }
            .background(Color.white.opacity(0.001))   // boşluk da sürüklenebilsin
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { v in if v.translation.height > 0 { drag = v.translation.height } }
                    .onEnded { v in
                        if v.translation.height > 110 || v.predictedEndTranslation.height > 240 {
                            onClose()
                        }
                        withAnimation(Motion.snappy) { drag = 0 }
                    }
            )
            Group {
                switch tab {
                case .market:    MarketScreen(game: game, feed: feed, onSelect: onSelect)
                case .portfolio: PortfolioScreen(game: game, feed: feed, onSelect: onSelect)
                case .forex:     ForexScreen(game: game)
                case .store:     StoreScreen(game: game)
                case .rankings:  RankingsScreen(game: game)
                case .settings:  SettingsScreen(game: game)
                case .map:       EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.bottom, 92)
        .liquidGlass(cornerRadius: Theme.rXl, interactive: false)
        .padding(.top, 96)
        .ignoresSafeArea(edges: .bottom)
        .offset(y: drag)
        .animation(.interactiveSpring(response: 0.3), value: drag)
    }
}
