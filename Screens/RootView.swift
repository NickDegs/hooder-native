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
                ScreenPanel(tab: tab, game: game, feed: feed, onSelect: { selected = $0 })
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
        .onAppear { feed.start() }
        .task {
            // Açılışta VIP entitlement kontrolü (abonelik aktifse anında uygulanır)
            Store.shared.onVIP = { active in game.isVIP = active }
            await Store.shared.refreshVIP()
        }
        .onReceive(tick) { _ in game.tickIncome(1) }
        .preferredColorScheme(.dark)
    }
}

// Harita-dışı sekme içeriğini taşıyan cam panel
private struct ScreenPanel: View {
    let tab: AppTab
    var game: GameState
    var feed: PropertyFeed
    var onSelect: (Property) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 38, height: 4).padding(.top, 10)
            Text(L10n.shared.t(tab.titleKey)).font(.h3).foregroundStyle(Theme.text).padding(.vertical, 8)
            Divider().background(.white.opacity(0.08))
            Group {
                switch tab {
                case .market:    MarketScreen(game: game, feed: feed, onSelect: onSelect)
                case .portfolio: PortfolioScreen(game: game, feed: feed, onSelect: onSelect)
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
    }
}
