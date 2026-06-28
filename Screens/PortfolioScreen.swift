import SwiftUI

// ── Portföy: sahip olunan mülkler + özet ──────────────────────────────────────
struct PortfolioScreen: View {
    var game: GameState
    var feed: PropertyFeed
    var onSelect: (Property) -> Void

    private var owned: [Property] { feed.all.filter { game.ownedIds.contains($0.id) } }
    private var dailyIncome: Double { owned.reduce(0) { $0 + $1.incomePerDay } }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Özet kartları
                HStack(spacing: 10) {
                    summary(L10n.shared.t("net_worth"), formatMoney(game.netWorth), Theme.gold)
                    summary(L10n.shared.t("daily_income"), "+\(formatMoney(dailyIncome))", Theme.green)
                }
                summary(L10n.shared.t("property_count"), "\(owned.count)", Theme.primary)
                    .frame(maxWidth: .infinity)

                if owned.isEmpty {
                    VStack(spacing: 6) {
                        Text("🗺️").font(.system(size: 34))
                        Text(L10n.shared.t("no_props")).font(.bodyB).foregroundStyle(Theme.textSub)
                    }.padding(.top, 40)
                } else {
                    ForEach(Array(owned.enumerated()), id: \.element.id) { i, p in
                        GlassCard(tint: Theme.green) {
                            HStack {
                                Text(p.category.emoji).font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.bodyB).foregroundStyle(Theme.text)
                                    Text("\(p.neighborhood) · +\(formatMoney(p.incomePerDay))/gün")
                                        .font(.captionB).foregroundStyle(Theme.textSub)
                                }
                                Spacer()
                                Text(formatMoney(p.price)).font(.captionB).foregroundStyle(Theme.gold)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(p) }
                        }
                        .appearIn(delay: min(0.25, Double(i) * 0.03))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8).padding(.bottom, 20)
        }
    }

    private func summary(_ title: String, _ value: String, _ color: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.label).foregroundStyle(Theme.textMuted)
                Text(value).font(.h2).foregroundStyle(color)
                    .contentTransition(.numericText())
            }
        }
    }
}
