import SwiftUI

// ── Mülk detay sheet'i — cam, yumuşak, kart-içi satın alma ────────────────────
struct PropertyDetailSheet: View {
    let property: Property
    var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false

    var body: some View {
        let owned = game.isOwned(property.id)
        let price = game.livePrice(property)
        let canAfford = game.cash >= price

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(property.category.emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text(property.name).font(.h2).foregroundStyle(Theme.text)
                    Text("\(property.neighborhood) · \(property.city)")
                        .font(.captionB).foregroundStyle(Theme.textSub)
                }
                Spacer()
            }

            // Prestij yıldızları
            HStack(spacing: 3) {
                ForEach(0..<5) { i in
                    Image(systemName: i < property.prestige ? "star.fill" : "star")
                        .font(.system(size: 12)).foregroundStyle(Theme.gold.opacity(i < property.prestige ? 1 : 0.3))
                }
            }

            HStack(spacing: 10) {
                stat(L10n.shared.t("price"), formatMoney(price), Theme.text)
                stat(L10n.shared.t("income_day"), "+\(formatMoney(property.incomePerDay))", Theme.green)
                stat("ROI", String(format: "%.1f%%", property.roiPercent), Theme.gold)
            }

            Spacer()

            if owned {
                Label(L10n.shared.t("owned_msg"), systemImage: "checkmark.seal.fill")
                    .font(.bodyB).foregroundStyle(Theme.green)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.green.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.rLg))
            } else if confirming {
                HStack(spacing: 10) {
                    GlassButton(tint: .gray, action: { withAnimation(Motion.snappy) { confirming = false } }) { Text(L10n.shared.t("cancel")) }
                    GlassButton(tint: Theme.green, action: {
                        if game.buy(property) { dismiss() }
                    }) { Text("\(L10n.shared.t("confirm")) — \(formatMoney(price))") }
                }
            } else {
                GlassButton(tint: canAfford ? Theme.primary : .gray, action: {
                    withAnimation(Motion.snappy) { confirming = true }
                }) { Text(canAfford ? "\(L10n.shared.t("buy")) — \(formatMoney(price))" : L10n.shared.t("low_funds")) }
                .disabled(!canAfford)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func stat(_ t: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(t).font(.label).foregroundStyle(Theme.textMuted)
            Text(v).font(.bodyB).foregroundStyle(c)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .liquidGlass(cornerRadius: Theme.rMd, interactive: false)
    }
}
