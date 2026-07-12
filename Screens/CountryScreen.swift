import SwiftUI

// ── MERKEZ BANKASI (ülke başına tek) — ülkeler arası ekonomik savaş ────────────
// Oyuncu ülkesini seçer. Ulusal hazineye katkı → ülke gücü + para birimi güçlenir.
// Ülkeler güce göre sıralanır (ekonomik savaş). Firma sekmesinin "Merkez Bankası" segmenti.
struct CountryScreen: View {
    var game: GameState
    @State private var mine: MyCountry?
    @State private var options: [Country] = []
    @State private var board: [CountryStanding] = []
    @State private var loaded = false
    @State private var contribAmt = ""
    @State private var msg: String?
    @State private var msgOK = false
    @State private var busy = false
    @State private var l10n = L10n.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let c = mine {
                    countryPanel(c)
                } else if loaded {
                    chooseCard()
                }
                if !board.isEmpty { boardCard() }
                if let msg {
                    Text(msg).font(.captionB)
                        .foregroundStyle(msgOK ? Theme.green : Color(red: 0.9, green: 0.4, blue: 0.4))
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.horizontal, 14)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8).padding(.bottom, 24)
        }
        .task { await reload() }
    }

    // ── ÜLKEM VAR ──
    private func countryPanel(_ c: MyCountry) -> some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text(c.flag).font(.system(size: 44))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name).font(.h2).foregroundStyle(Theme.text)
                            Text("#\(c.rank)/\(c.total) · \(c.players) \(l10n.t("cb_players"))")
                                .font(.captionB).foregroundStyle(Theme.textSub)
                        }
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        stat(l10n.t("cb_power"), formatMoney(c.power), Theme.gold)
                        stat(l10n.t("cb_treasury"), formatMoney(c.treasury), Theme.green)
                    }
                    if let rate = c.rate {
                        Text("\(c.ccy) · 1 USD = \(String(format: rate < 1 ? "%.4f" : "%.2f", rate)) \(c.ccy)")
                            .font(.captionB).foregroundStyle(Theme.textMuted)
                    } else {
                        Text("\(c.ccy) · \(l10n.t("cb_base_currency"))").font(.captionB).foregroundStyle(Theme.textMuted)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label(l10n.t("cb_contribute"), systemImage: "banknote.fill").font(.bodyB).foregroundStyle(Theme.text)
                    Text(l10n.t("cb_contribute_hint")).font(.captionB).foregroundStyle(Theme.textSub)
                    HStack(spacing: 8) {
                        TextField(l10n.t("firm_amount_ph"), text: $contribAmt)
                            .keyboardType(.numberPad)
                            .font(.bodyB).foregroundStyle(Theme.text)
                            .padding(.horizontal, 12).frame(height: 44)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        GlassButton(tint: Theme.gold, action: contribute) { Text(l10n.t("firm_contribute")) }
                    }
                }
            }
        }
    }

    // ── ÜLKEM YOK: SEÇ ──
    private func chooseCard() -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(l10n.t("cb_choose"), systemImage: "flag.2.crossed.fill").font(.bodyB).foregroundStyle(Theme.gold)
                Text(l10n.t("cb_choose_hint")).font(.captionB).foregroundStyle(Theme.textSub)
                ForEach(options) { o in
                    HStack(spacing: 10) {
                        Text(o.flag).font(.system(size: 26))
                        Text(o.name).font(.bodyB).foregroundStyle(Theme.text)
                        Text(o.ccy).font(.label).foregroundStyle(Theme.textMuted)
                        Spacer()
                        GlassButton(tint: Theme.primary, action: { join(o.cc) }) { Text(l10n.t("cb_choose_btn")) }
                    }
                }
            }
        }
    }

    // ── EKONOMİK SAVAŞ SIRALAMASI ──
    private func boardCard() -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(l10n.t("cb_war"), systemImage: "globe.europe.africa.fill").font(.bodyB).foregroundStyle(Theme.gold)
                ForEach(board) { c in
                    HStack(spacing: 8) {
                        Text("\(c.rank)").font(.captionB).foregroundStyle(Theme.textMuted).frame(width: 20, alignment: .leading)
                        Text(c.flag).font(.captionB)
                        Text(c.name).font(.captionB).foregroundStyle(mine?.cc == c.cc ? Theme.primary : Theme.text)
                        Spacer()
                        Text(formatMoney(c.power)).font(.captionB).foregroundStyle(Theme.green)
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
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    // ── Aksiyonlar ──
    private func reload() async {
        let m = await BackendService.shared.countryMine()
        let b = await BackendService.shared.countryLeaderboard()
        var o: [Country] = []
        if m == nil { o = await BackendService.shared.countryList() }
        await MainActor.run { mine = m; board = b; options = o; loaded = true }
    }
    private func join(_ cc: String) {
        guard !busy else { return }; busy = true
        Task { let ok = await BackendService.shared.countryJoin(cc); await finish(ok, l10n.t("cb_msg_joined")) }
    }
    private func contribute() {
        guard let a = Double(contribAmt), a >= 1, !busy else { return }
        guard a <= game.cash else { msgOK = false; msg = l10n.t("low_funds"); return }
        busy = true
        Task {
            let ok = await BackendService.shared.countryContribute(a)
            if ok { await MainActor.run { game.cash -= a; contribAmt = "" } }
            await finish(ok, l10n.t("cb_msg_contributed"))
        }
    }
    private func finish(_ ok: Bool, _ okMsg: String) async {
        await MainActor.run { busy = false; msgOK = ok; msg = ok ? okMsg : l10n.t("firm_msg_fail") }
        await reload()
    }
}
