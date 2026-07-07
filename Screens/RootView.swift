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
            // TANITIM TURU: backend'e GİTME (CF edge datacenter/CI IP'sini bloklar → /anon 403).
            // Kimliği atla (markReadyForSnapshot), mülkler Mapbox tilequery'den gelir (backend'siz),
            // cüzdan/ekonomi yerel varsayılanlarla dolu görünür. Sadece görsel çekim içindir.
            if Demo.active {
                if let l = Demo.lang { L10n.shared.lang = l }
                auth.markReadyForSnapshot()
                await runDemo()
                return
            }
            await startup()
        }
        .preferredColorScheme(.dark)
    }

    // ── Tanıtım turu: akıcı sekme + kamera geçişleriyle oyunu özetler (~70 sn) ──
    // CI kaydı ~12 sn geç ısınır + uzak şehir tile'ları ağdan iner → uzun duraklar.
    // Kesim/temposunu ffmpeg yapar; burada her sahneye bolca süre tanınır.
    @MainActor private func runDemo() async {
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        var waited = 0.0
        while waited < 40, feed.all.count < 40 { await wait(1); waited += 1 }   // mülkler insin
        await wait(max(0, 18 - waited))                   // kayıt kesin aktif + İstanbul tile'ları
        await wait(6.0)                                   // İstanbul vitrini
        if let p = feed.all.max(by: { $0.price < $1.price }) { selected = p }   // değerli mülkü aç
        await wait(4.0)
        selected = nil
        await wait(0.8)
        demoFly = Demo.newYork                            // Manhattan'a uç
        await wait(9.0)                                   // tile'lar insin + vitrin
        withAnimation(Motion.smooth) { tab = .market }    // canlı piyasa (mülk listesi)
        await wait(3.2)
        withAnimation(Motion.smooth) { tab = .forex }     // döviz al-sat
        await wait(3.0)
        withAnimation(Motion.smooth) { tab = .store }     // VIP mağaza (altın kart)
        await wait(3.2)
        withAnimation(Motion.smooth) { tab = .map }
        demoFly = Demo.paris                              // Paris'e uç
        await wait(9.0)
        withAnimation(Motion.smooth) { tab = .map }
        demoFly = Demo.dubai                              // Dubai'ye uç (final)
        await wait(11.0)
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
