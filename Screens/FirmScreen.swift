import SwiftUI

// ── EMLAK FİRMASI (klan) — sohbetsiz dayanışma + ortak kasa ────────────────────
// Firman yoksa: kur ya da katıl. Firman varsa: kasaya katkı (havuz — alıcı seçilmez),
// günde bir kez kasadan destek al (%20 vergi), üyeler, firma sıralaması.
struct FirmScreen: View {
    var game: GameState
    @State private var mine: MyFirm?
    @State private var list: [Firm] = []
    @State private var board: [Firm] = []
    @State private var loaded = false
    @State private var newName = ""
    @State private var emblem = "🏢"
    @State private var contribAmt = ""
    @State private var msg: String?
    @State private var msgOK = false
    @State private var busy = false
    @State private var seg = 0
    @State private var l10n = L10n.shared

    private let emblems = ["🏢","🏙️","🏰","💎","👑","🦁","🚀","⚡️","🔥","🌆"]

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $seg) {
                Text(l10n.t("tab_firm")).tag(0)
                Text(l10n.t("cb_title")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 2)

            if seg == 1 {
                CountryScreen(game: game)
            } else {
            ScrollView {
            VStack(spacing: 12) {
                if let f = mine?.firm {
                    firmPanel(f)
                } else if loaded {
                    createCard()
                    if !list.isEmpty { joinList() }
                }
                if !board.isEmpty { boardCard() }
                if let msg {
                    Text(msg).font(.captionB)
                        .foregroundStyle(msgOK ? Theme.green : Color(red: 0.9, green: 0.4, blue: 0.4))
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8).padding(.bottom, 24)
        }
        .task { await reload() }
            }
        }
    }

    // ── FİRMAM VAR ──
    private func firmPanel(_ f: Firm) -> some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text(f.emblem).font(.system(size: 40))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.name).font(.h2).foregroundStyle(Theme.text)
                            Text("\(f.members) · \(l10n.t("firm_members"))").font(.captionB).foregroundStyle(Theme.textSub)
                        }
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        stat(l10n.t("firm_treasury"), formatMoney(f.treasury), Theme.gold)
                        stat(l10n.t("net_worth"), formatMoney(f.netWorth), Theme.green)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label(l10n.t("firm_contribute"), systemImage: "arrow.down.circle.fill").font(.bodyB).foregroundStyle(Theme.text)
                    Text(l10n.t("firm_contribute_hint")).font(.captionB).foregroundStyle(Theme.textSub)
                    HStack(spacing: 8) {
                        TextField(l10n.t("firm_amount_ph"), text: $contribAmt)
                            .keyboardType(.numberPad)
                            .font(.bodyB).foregroundStyle(Theme.text)
                            .padding(.horizontal, 12).frame(height: 44)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        GlassButton(tint: Theme.primary, action: contribute) { Text(l10n.t("firm_contribute")) }
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label(l10n.t("firm_aid"), systemImage: "lifepreserver.fill").font(.bodyB).foregroundStyle(Theme.green)
                    Text(String(format: l10n.t("firm_aid_hint"), formatMoney(mine?.aidNet ?? 2_000_000))).font(.captionB).foregroundStyle(Theme.textSub)
                    if let rec = mine?.myReceived, rec > 0 {
                        Text("\(l10n.t("firm_received")): \(formatMoney(rec))").font(.captionB).foregroundStyle(Theme.textMuted)
                    }
                    GlassButton(tint: Theme.green, action: claimAid) { Text(l10n.t("firm_aid")) }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label(l10n.t("firm_members"), systemImage: "person.3.fill").font(.bodyB).foregroundStyle(Theme.text)
                    ForEach(mine?.members ?? []) { mm in
                        HStack {
                            Text(mm.role == "owner" ? "👑" : "•").font(.captionB)
                            Text(mm.isMe ? l10n.t("firm_you") : "#\(mm.uid.suffix(5))")
                                .font(.captionB).foregroundStyle(mm.isMe ? Theme.primary : Theme.textSub)
                            Spacer()
                            Text(formatMoney(mm.contributed)).font(.captionB).foregroundStyle(Theme.gold)
                        }
                    }
                }
            }

            GlassButton(tint: Color(red: 0.9, green: 0.35, blue: 0.35), action: leave) { Text(l10n.t("firm_leave")) }
        }
    }

    // ── FİRMAM YOK: KUR ──
    private func createCard() -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(l10n.t("firm_create"), systemImage: "building.2.crop.circle.fill").font(.bodyB).foregroundStyle(Theme.gold)
                Text(l10n.t("firm_create_hint")).font(.captionB).foregroundStyle(Theme.textSub)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(emblems, id: \.self) { e in
                            Text(e).font(.system(size: 24))
                                .frame(width: 42, height: 42)
                                .background((emblem == e ? Theme.primary.opacity(0.22) : .white.opacity(0.05)), in: Circle())
                                .onTapGesture { withAnimation(Motion.snappy) { emblem = e } }
                        }
                    }
                }
                TextField(l10n.t("firm_name_ph"), text: $newName)
                    .font(.bodyB).foregroundStyle(Theme.text)
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                HStack {
                    Text("\(l10n.t("firm_create_cost")): \(formatMoney(5_000_000))").font(.captionB).foregroundStyle(Theme.textMuted)
                    Spacer()
                    GlassButton(tint: Theme.gold, action: create) { Text(l10n.t("firm_create")) }
                }
            }
        }
    }

    // ── FİRMAM YOK: KATIL ──
    private func joinList() -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(l10n.t("firm_join_title"), systemImage: "person.badge.plus").font(.bodyB).foregroundStyle(Theme.text)
                ForEach(list) { f in
                    HStack(spacing: 10) {
                        Text(f.emblem).font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.name).font(.bodyB).foregroundStyle(Theme.text)
                            Text("\(f.members) · \(formatMoney(f.netWorth))").font(.label).foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        GlassButton(tint: Theme.primary, action: { join(f.id) }) { Text(l10n.t("firm_join")) }
                    }
                }
            }
        }
    }

    // ── FİRMA SIRALAMASI ──
    private func boardCard() -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(l10n.t("firm_board"), systemImage: "trophy.fill").font(.bodyB).foregroundStyle(Theme.gold)
                ForEach(Array(board.enumerated()), id: \.element.id) { i, f in
                    HStack {
                        Text("\(i + 1)").font(.captionB).foregroundStyle(Theme.textMuted).frame(width: 20, alignment: .leading)
                        Text(f.emblem).font(.captionB)
                        Text(f.name).font(.captionB).foregroundStyle(Theme.text)
                        Spacer()
                        Text(formatMoney(f.netWorth)).font(.captionB).foregroundStyle(Theme.green)
                    }
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.h3).foregroundStyle(tint)
            Text(label).font(.label).foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    // ── Aksiyonlar ──
    private func reload() async {
        let m = await BackendService.shared.firmMine()
        let b = await BackendService.shared.firmLeaderboard()
        var l: [Firm] = []
        if m?.firm == nil { l = await BackendService.shared.firmList() }
        await MainActor.run { mine = m; board = b; list = l; loaded = true }
    }

    private func create() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        guard n.count >= 2, !busy else { return }
        guard game.cash >= 5_000_000 else { msgOK = false; msg = l10n.t("low_funds"); return }
        busy = true
        Task {
            let r = await BackendService.shared.firmCreate(name: n, emblem: emblem)
            if r.ok { await MainActor.run { game.cash -= 5_000_000; newName = "" } }
            await finish(r.ok, l10n.t("firm_msg_created"), r.error)
        }
    }
    private func join(_ id: String) {
        guard !busy else { return }; busy = true
        Task { let ok = await BackendService.shared.firmJoin(id); await finish(ok, l10n.t("firm_msg_joined"), nil) }
    }
    private func contribute() {
        guard let a = Double(contribAmt), a >= 1, !busy else { return }
        guard a <= game.cash else { msgOK = false; msg = l10n.t("low_funds"); return }
        busy = true
        Task {
            let ok = await BackendService.shared.firmContribute(a)
            if ok { await MainActor.run { game.cash -= a; contribAmt = "" } }
            await finish(ok, l10n.t("firm_msg_contributed"), nil)
        }
    }
    private func claimAid() {
        guard !busy else { return }; busy = true
        Task {
            let r = await BackendService.shared.firmAid()
            if r.ok { await MainActor.run { game.cash += r.received } }
            await finish(r.ok, String(format: l10n.t("firm_msg_aid"), formatMoney(r.received)), r.error)
        }
    }
    private func leave() {
        guard !busy else { return }; busy = true
        Task { let ok = await BackendService.shared.firmLeave(); await finish(ok, l10n.t("firm_msg_left"), nil) }
    }
    private func finish(_ ok: Bool, _ okMsg: String, _ err: String?) async {
        await MainActor.run { busy = false; msgOK = ok; msg = ok ? okMsg : (err ?? l10n.t("firm_msg_fail")) }
        await reload()
    }
}
