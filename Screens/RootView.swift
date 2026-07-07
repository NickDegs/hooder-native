import SwiftUI
import CoreLocation

// ── Kök kabuk: harita arka planda, üstte HUD + içerik + cam sekme çubuğu ──────
struct RootView: View {
    @State private var game = GameState()
    @State private var feed = PropertyFeed.shared
    @State private var auth = AuthService.shared
    @State private var tab: AppTab = Snapshot.initialTab ?? .map
    @State private var selected: Property?
    @State private var syncCounter = 0
    @State private var connecting = true
    @State private var demoFly: CLLocationCoordinate2D?   // tanıtım turu kamera hedefi

    // saniyede bir gelir tahakkuku
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if auth.ready { gameView }                       // kimlik alındı → oyun
            else { LockView(connecting: connecting) { await startup() } }   // yoksa KİLİT
        }
        .task {
            if Snapshot.active { auth.markReadyForSnapshot(); return }
            await startup()
            if Demo.active, auth.ready { await runDemo() }   // tanıtım turu (yalnız -demo)
        }
        .preferredColorScheme(.dark)
    }

    // ── Tanıtım turu: akıcı sekme + kamera geçişleriyle oyunu özetler (~30 sn) ──
    @MainActor private func runDemo() async {
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        await wait(4.0)                                   // İstanbul haritası + pill'ler otursun
        if let p = feed.all.max(by: { $0.price < $1.price }) { selected = p }   // değerli mülkü aç
        await wait(3.4)
        selected = nil
        await wait(0.6)
        demoFly = Demo.newYork                            // Manhattan'a uç
        await wait(4.2)
        withAnimation(Motion.smooth) { tab = .market }    // canlı piyasa
        await wait(3.0)
        withAnimation(Motion.smooth) { tab = .store }     // VIP mağaza
        await wait(3.0)
        withAnimation(Motion.smooth) { tab = .rankings }  // liderlik
        await wait(2.8)
        withAnimation(Motion.smooth) { tab = .map }
        demoFly = Demo.paris                              // Paris'e uç
        await wait(3.8)
        withAnimation(Motion.smooth) { tab = .portfolio } // portföy
        await wait(2.8)
        withAnimation(Motion.smooth) { tab = .map }
        demoFly = Demo.dubai                              // Dubai'ye uç (final)
        await wait(4.0)
    }

    // İlk açılış akışı: ZORUNLU sunucu kimliği → sonra cüzdan/store
    private func startup() async {
        connecting = true
        await auth.authenticate()
        connecting = false
        guard auth.ready else { return }                     // token yoksa oyun açılmaz
        await game.syncWallet()
        Store.shared.onGrant = { jws in game.grantIAP(jws: jws) }
        Store.shared.onVIP = { active in game.isVIP = active }
        Store.shared.onVIPProof = { jws in game.proveVIP(jws: jws) }
        await Store.shared.refreshVIP()
    }

    private var gameView: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            // Harita HER ZAMAN arka planda
            MapScreen(game: game, feed: feed, onSelect: { selected = $0 }, externalFly: demoFly)
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
        .onAppear { Snapshot.applyLang(); feed.start(); EconomyService.shared.start() }   // canlı ekonomi başlasın
        .onReceive(tick) { _ in
            game.tickIncome(1)
            syncCounter += 1
            if syncCounter % 25 == 0 { Task { await game.syncWallet() } }   // ~25 sn'de bir sunucu gerçeğine hizala
        }
    }
}

// ── KİLİT EKRANI: sunucu kimliği/internet yoksa oyun açılmaz (korsan/offline engeli) ──
struct LockView: View {
    let connecting: Bool
    let retry: () async -> Void
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60)).foregroundStyle(Theme.primary)
                Text("Hooder").font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.text)
                Text(connecting ? L10n.shared.t("auth_checking") : L10n.shared.t("auth_required"))
                    .font(.h3).foregroundStyle(Theme.textSub)
                Text(L10n.shared.t("auth_online_note"))
                    .font(.bodyB).foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center).padding(.horizontal, 44)
                if connecting {
                    ProgressView().tint(Theme.primary).padding(.top, 4)
                } else {
                    Button { Task { await retry() } } label: {
                        Text(L10n.shared.t("retry")).font(.bodyB).foregroundStyle(.white)
                            .padding(.horizontal, 30).frame(height: 52)
                            .background(Theme.primary, in: Capsule())
                    }.buttonStyle(.plain).padding(.top, 6)
                }
            }
        }
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
