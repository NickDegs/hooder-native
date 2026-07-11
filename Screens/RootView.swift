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
    @State private var demoOrbit = false                  // tanıtım: tile'lar hazır → sürekli akıcı orbit

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

    // ── Tanıtım turu: Manhattan'da SİNEMATİK ORBİT (kamera yavaş döner, etiketler belirir) ──
    // Harita PropertyMapView'de sürekli döner (cinematic); burada sadece vitrin süresi +
    // arada mülk detayı ve kısa Market/Forex açılır. Kesim/FPS'i ffmpeg (minterpolate) yapar.
    // Manhattan içinde ikonik duraklar — her yavaş uçuş sonrası kamera DURUR → uydu tile'ı
    // iner + mülk etiketleri belirir (sürekli orbit tile yüklemeyi engelliyordu; bu çalışır).
    // Şehir merkezinden küçük ofsetli duraklar — hangi şehir olursa olsun (Demo.cityCenter)
    // merkez çevresinde ~600m'lik yavaş uçuşlar; her durakta kamera durur → tile+etiket belirir.
    private var cityStops: [CLLocationCoordinate2D] {
        let c = Demo.cityCenter ?? Demo.newYork
        return [
            CLLocationCoordinate2D(latitude: c.latitude - 0.004, longitude: c.longitude + 0.006),
            CLLocationCoordinate2D(latitude: c.latitude + 0.006, longitude: c.longitude - 0.004),
            CLLocationCoordinate2D(latitude: c.latitude + 0.003, longitude: c.longitude + 0.005),
        ]
    }

    @MainActor private func runDemo() async {
        func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        var waited = 0.0
        while waited < 35, feed.all.count < 30 { await wait(1); waited += 1 }   // mülkler insin
        game.demoSeed(feed.all)                           // Portföy + net değer DOLU görünsün
        // Mapbox SDK config servisi + ilk tile indirmesi CI'da ~30-40sn sürüyor. Kamera SABİT
        // dururken uzun bekle → tile'lar TAM cache'lensin + render olsun (ölü başlangıç post'ta kesilir).
        // Tile'lar cache'lendikten SONRA orbit başlar → cache'li tile üzerinde AKICI 3D dönüş
        // (tile-yükleme takılması yok = "donma" yok). Etiketler/fiyat baloncukları kamerayla döner.
        await wait(34.0)
        demoOrbit = true                                  // ← SÜREKLİ AKICI SİNEMATİK ORBİT BAŞLA
        await wait(13.0)                                  // 13sn kesintisiz akıcı orbit (montaj bundan kesilir)
        if let p = feed.all.max(by: { $0.price < $1.price }) { selected = p }   // gerçek mülk baloncuğu → detay
        await wait(3.5)
        selected = nil
        await wait(13.0)                                  // orbit sürerken daha fazla akıcı hareket
        // Kısa uygulama özeti (statik ekranlar → simülatörde akıcı); harita arkada dönmeye devam eder
        withAnimation(Motion.smooth) { tab = .market };    await wait(2.6)   // canlı piyasa
        withAnimation(Motion.smooth) { tab = .portfolio }; await wait(2.6)   // dolu portföy
        withAnimation(Motion.smooth) { tab = .map };       await wait(2.0)
        await wait(12.0)                                  // final akıcı orbit
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
            MapScreen(game: game, feed: feed, onSelect: { selected = $0 }, externalFly: demoFly,
                      cinematicOrbit: demoOrbit)
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
