import SwiftUI
import StoreKit

// ── Mağaza: nakit paketleri (StoreKit 2) ──────────────────────────────────────
struct StoreScreen: View {
    var game: GameState
    @State private var store = Store.shared
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // ── VIP üyelik ────────────────────────────────────────────────
                vipSection
                    .padding(.horizontal, 14)

                Text("💰 \(L10n.shared.t("cash_packs"))").font(.h3).foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.top, 6)

                if store.products.isEmpty {
                    ProgressView().tint(.white).padding(.top, 30)
                    Text("Paketler yükleniyor…").font(.captionB).foregroundStyle(Theme.textMuted)
                } else {
                    ForEach(store.products, id: \.id) { product in
                        GlassCard(tint: Theme.gold) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(product.displayName).font(.bodyB).foregroundStyle(Theme.text)
                                    if let cash = Store.cashFor[product.id] {
                                        Text("+\(formatMoney(cash)) nakit").font(.captionB).foregroundStyle(Theme.green)
                                    }
                                }
                                Spacer()
                                GlassButton(tint: Theme.gold, action: {
                                    Task { await store.buy(product) }
                                }) {
                                    if store.purchasingId == product.id {
                                        ProgressView().tint(.black)
                                    } else {
                                        Text(product.displayPrice)
                                    }
                                }
                                .frame(width: 110)
                            }
                        }
                        .appearIn()
                    }
                }
            }
            .padding(.vertical, 8).padding(.bottom, 20)
        }
        .overlay(alignment: .bottom) { if let toast { ToastView(text: toast).padding(.bottom, 100) } }
        .task {
            store.onCredit = { amount in
                game.credit(amount)
                withAnimation(Motion.glass) { toast = "+\(formatMoney(amount)) eklendi ✅" }
                Task { try? await Task.sleep(for: .seconds(2.2)); withAnimation { toast = nil } }
            }
            store.onVIP = { active in
                game.isVIP = active
                if active { withAnimation(Motion.glass) { toast = "👑 VIP aktif!" }
                    Task { try? await Task.sleep(for: .seconds(2.2)); withAnimation { toast = nil } } }
            }
            await store.load()
            await store.deliverPending()
        }
    }

    // ── VIP üyelik bölümü ─────────────────────────────────────────────────────
    @ViewBuilder private var vipSection: some View {
        GlassCard(tint: Theme.gold, sweep: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("\(L10n.shared.t("vip_title"))", systemImage: "crown.fill")
                        .font(.h3).foregroundStyle(Theme.gold)
                    Spacer()
                    if game.isVIP {
                        Text(L10n.shared.t("vip_active")).font(.captionB).foregroundStyle(Theme.green)
                    }
                }
                // Avantajlar
                VStack(alignment: .leading, spacing: 4) {
                    perk("📈 " + L10n.shared.t("vip_perk_income"))
                    perk("👑 " + L10n.shared.t("vip_perk_badge"))
                    perk("💎 " + L10n.shared.t("vip_perk_exclusive"))
                }
                if !game.isVIP {
                    if store.vipProducts.isEmpty {
                        Text(L10n.shared.t("loading")).font(.captionB).foregroundStyle(Theme.textMuted)
                    } else {
                        HStack(spacing: 8) {
                            ForEach(store.vipProducts, id: \.id) { p in
                                Button { Task { await store.buy(p) } } label: {
                                    VStack(spacing: 1) {
                                        Text(p.displayName).font(.system(size: 11, weight: .bold))
                                        Text(p.displayPrice).font(.system(size: 13, weight: .heavy))
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(Theme.gold, in: RoundedRectangle(cornerRadius: 14))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Apple 3.1.2 ZORUNLU: abonelik açıklaması + Gizlilik/Şartlar linkleri
                VStack(spacing: 6) {
                    Text(L10n.shared.t("sub_disclosure"))
                        .font(.system(size: 10)).foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        Link(L10n.shared.t("privacy"), destination: URL(string: "https://realvirtuality.app/hooder-api/privacy")!)
                        Link(L10n.shared.t("terms"), destination: URL(string: "https://realvirtuality.app/hooder-api/terms")!)
                        Spacer()
                    }
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.primary)
                }
                .padding(.top, 6)
            }
        }
    }

    private func perk(_ s: String) -> some View {
        Text(s).font(.captionB).foregroundStyle(Theme.textSub)
    }
}
