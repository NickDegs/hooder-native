import SwiftUI
import StoreKit

// ── Mağaza: nakit paketleri (StoreKit 2) ──────────────────────────────────────
struct StoreScreen: View {
    var game: GameState
    @State private var store = Store()
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("💰 \(L10n.shared.t("cash_packs"))").font(.h3).foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14)

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
            await store.load()
            await store.deliverPending()
        }
    }
}
