import SwiftUI

// ── Tekrar kullanılır mülk satırı (Piyasa + alan listesi) ─────────────────────
// Kart-İÇİ satın alma onayı (overlay/popup YOK → asla siyah ekran).
struct PropertyRowView: View {
    let property: Property
    var game: GameState
    var onSelect: (Property) -> Void
    var onToast: (String) -> Void
    @State private var confirming = false

    var body: some View {
        let owned = game.isOwned(property.id)
        let price = game.livePrice(property)
        let canAfford = game.cash >= price
        GlassCard(tint: property.vipOnly ? Theme.gold : .clear) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(property.category.emoji) \(property.category.title.uppercased())")
                        .font(.label).foregroundStyle(Theme.primary)
                    Spacer()
                    Text(String(format: "%.1f%% ROI", property.roiPercent))
                        .font(.captionB).foregroundStyle(Theme.gold)
                }
                Text(property.name).font(.h3).foregroundStyle(Theme.text)
                Text("\(property.neighborhood) · \(property.city)")
                    .font(.captionB).foregroundStyle(Theme.textSub)
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(formatMoney(price)).font(.bodyB).foregroundStyle(Theme.text)
                        Text("+\(formatMoney(property.incomePerDay))/gün")
                            .font(.captionB).foregroundStyle(Theme.green)
                    }
                    Spacer()
                    buyControl(owned: owned, price: price, canAfford: canAfford)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect(property) }
        }
    }

    @ViewBuilder private func buyControl(owned: Bool, price: Double, canAfford: Bool) -> some View {
        if property.vipOnly && !game.isVIP {
            Label("VIP", systemImage: "crown.fill")
                .font(.captionB).foregroundStyle(Theme.gold)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.gold.opacity(0.16), in: Capsule())
        } else if owned {
            Label(L10n.shared.t("owned"), systemImage: "checkmark.seal.fill")
                .font(.captionB).foregroundStyle(Theme.green)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.green.opacity(0.14), in: Capsule())
        } else if confirming {
            HStack(spacing: 6) {
                Button { withAnimation(Motion.snappy) { confirming = false } } label: {
                    Text(L10n.shared.t("cancel")).font(.captionB).foregroundStyle(Theme.textSub)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                }.buttonStyle(.plain)
                Button {
                    let ok = game.buy(property)
                    onToast(ok ? "\(property.name) alındı ✅" : "Yetersiz bakiye ❌")
                    withAnimation(Motion.snappy) { confirming = false }
                } label: {
                    Text("✓ \(formatMoney(price))").font(.captionB).foregroundStyle(.black)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.green, in: Capsule())
                }.buttonStyle(.plain)
            }
        } else {
            Button { withAnimation(Motion.snappy) { confirming = true } } label: {
                Text(canAfford ? L10n.shared.t("buy") : L10n.shared.t("insufficient")).font(.captionB)
                    .foregroundStyle(canAfford ? .black : Theme.textMuted)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(canAfford ? Theme.primary : Color.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canAfford)
        }
    }
}
