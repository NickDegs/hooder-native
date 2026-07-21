import SwiftUI

// ── Üst HUD: logo + seviye + nakit (canlı, yumuşak değişim) ────────────────────
struct HUDBar: View {
    var game: GameState

    var body: some View {
        HStack(spacing: 10) {
            // Logo + seviye
            HStack(spacing: 8) {
                Text("🏙️").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text("Hooder").font(.h3).foregroundStyle(Theme.text)
                        if game.isVIP {
                            Label("VIP", systemImage: "crown.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.gold, in: Capsule())
                        }
                    }
                    Text("\(L10n.shared.t("level_abbr"))\(game.level) \(L10n.shared.t("investor"))").font(.label).foregroundStyle(Theme.textMuted)
                }
            }
            Spacer()
            // Nakit (sayı değişimi yumuşak)
            VStack(alignment: .trailing, spacing: 1) {
                Text(formatMoney(game.cash))
                    .font(.h3).foregroundStyle(Theme.gold)
                    .contentTransition(.numericText(value: game.cash))
                    .animation(Motion.smooth, value: game.cash)
                Text(L10n.shared.t("cash")).font(.label).foregroundStyle(Theme.gold.opacity(0.55))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .liquidGlass(cornerRadius: Theme.rXl, interactive: false)
        .padding(.horizontal, 14)
    }
}
