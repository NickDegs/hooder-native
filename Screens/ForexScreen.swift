import SwiftUI

// ── Döviz / Forex — canlı kurlarla al-sat ─────────────────────────────────────
struct ForexScreen: View {
    var game: GameState
    @State private var econ = EconomyService.shared
    @State private var buyTarget: (code: String, flag: String, name: String)?
    @State private var amount = ""
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Piyasa endeksi (canlı)
                GlassCard(tint: Theme.primary) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.shared.t("market_index")).font(.label).foregroundStyle(Theme.textMuted)
                            Text(String(format: "%.3f", econ.marketIndex)).font(.h2).foregroundStyle(Theme.text)
                                .contentTransition(.numericText(value: econ.marketIndex))
                        }
                        Spacer()
                        changeChip(econ.indexChange)
                    }
                }

                ForEach(econ.currencies, id: \.code) { c in
                    let rate = econ.rates[c.code] ?? 0
                    let pos = game.fx[c.code]
                    GlassCard {
                        VStack(spacing: 8) {
                            HStack {
                                Text(c.flag).font(.system(size: 24))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(c.code).font(.bodyB).foregroundStyle(Theme.text)
                                    Text(c.name).font(.label).foregroundStyle(Theme.textMuted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(String(format: "%.4f", rate)).font(.bodyB).foregroundStyle(Theme.text)
                                        .contentTransition(.numericText(value: rate))
                                    changeChip(econ.change(c.code))
                                }
                            }
                            if let pos, pos.units > 0 {
                                let usdNow = rate > 0 ? pos.units / rate : 0
                                let pl = usdNow - pos.costUSD
                                HStack {
                                    Text("\(formatUnits(pos.units)) \(c.code)").font(.captionB).foregroundStyle(Theme.textSub)
                                    Spacer()
                                    Text("\(pl >= 0 ? "+" : "")\(formatMoney(pl))")
                                        .font(.captionB).foregroundStyle(pl >= 0 ? Theme.green : .red)
                                    Button {
                                        let pl = game.sellFx(c.code, rate: rate)
                                        showToast("\(c.code) \(L10n.shared.t("sold")): \(pl >= 0 ? "+" : "")\(formatMoney(pl))")
                                    } label: {
                                        Text(L10n.shared.t("sell")).font(.captionB).foregroundStyle(.black)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Theme.green, in: Capsule())
                                    }.buttonStyle(.plain)
                                }
                            } else {
                                Button { amount = "100000"; buyTarget = c } label: {
                                    Text(L10n.shared.t("buy")).font(.captionB).foregroundStyle(.black)
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                        .background(Theme.primary, in: Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8).padding(.bottom, 20)
        }
        .overlay(alignment: .bottom) { if let toast { ToastView(text: toast).padding(.bottom, 100) } }
        .alert("\(L10n.shared.t("buy")) \(buyTarget?.code ?? "")", isPresented: Binding(get: { buyTarget != nil }, set: { if !$0 { buyTarget = nil } })) {
            TextField("USD", text: $amount).keyboardType(.numberPad)
            Button(L10n.shared.t("cancel"), role: .cancel) { buyTarget = nil }
            Button(L10n.shared.t("buy")) {
                if let c = buyTarget, let usd = Double(amount.filter(\.isNumber)) {
                    let ok = game.buyFx(c.code, usdAmount: usd, rate: econ.rates[c.code] ?? 0)
                    showToast(ok ? "\(formatMoney(usd)) → \(c.code) ✅" : L10n.shared.t("low_funds"))
                }
                buyTarget = nil
            }
        } message: { Text("\(L10n.shared.t("cash")): \(formatMoney(game.cash))") }
    }

    private func changeChip(_ pct: Double) -> some View {
        let up = pct >= 0
        return Text("\(up ? "▲" : "▼") \(String(format: "%.2f%%", abs(pct)))")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(up ? Theme.green : .red)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background((up ? Theme.green : .red).opacity(0.15), in: Capsule())
    }

    private func formatUnits(_ v: Double) -> String {
        v >= 1_000_000 ? String(format: "%.1fM", v/1_000_000) : v >= 1000 ? String(format: "%.0fK", v/1000) : String(format: "%.0f", v)
    }
    private func showToast(_ s: String) {
        withAnimation(Motion.glass) { toast = s }
        Task { try? await Task.sleep(for: .seconds(2.2)); withAnimation { toast = nil } }
    }
}
