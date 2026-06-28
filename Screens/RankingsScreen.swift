import SwiftUI

// ── Sıralama: canlı liderlik (backend); offline'da yerel mock + sen ───────────
struct RankingsScreen: View {
    var game: GameState
    @State private var backend = BackendService.shared

    private struct Row: Identifiable { let id: String; let name: String; let net: Double; let me: Bool }

    private var board: [Row] {
        if backend.online && !backend.leaders.isEmpty {
            var rows = backend.leaders.map { Row(id: $0.id, name: $0.name, net: $0.netWorth, me: $0.name == "SEN") }
            if !rows.contains(where: { $0.me }) {
                rows.append(Row(id: "me", name: "SEN", net: game.netWorth, me: true))
            }
            return rows.sorted { $0.net > $1.net }
        }
        // Offline mock
        let bots = [
            ("Emir Holding", 480_000_000.0), ("Defne Yatırım", 312_000_000),
            ("Kaya Group", 198_000_000), ("Marina Estates", 154_000_000),
            ("Atlas Realty", 96_000_000), ("Boğaz Capital", 61_000_000),
        ]
        var all = bots.enumerated().map { Row(id: "bot\($0.offset)", name: $0.element.0, net: $0.element.1, me: false) }
        all.append(Row(id: "me", name: "SEN", net: game.netWorth, me: true))
        return all.sorted { $0.net > $1.net }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if backend.online {
                    Label(L10n.shared.t("live_board"), systemImage: "dot.radiowaves.left.and.right")
                        .font(.label).foregroundStyle(Theme.green)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                }
                ForEach(Array(board.enumerated()), id: \.element.id) { i, p in
                    GlassCard(tint: p.me ? Theme.primary : .clear) {
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(.h3)
                                .foregroundStyle(i < 3 ? Theme.gold : Theme.textMuted).frame(width: 28)
                            Text(p.me ? "👤" : "🏢").font(.system(size: 20))
                            Text(p.name).font(.bodyB).foregroundStyle(p.me ? Theme.primary : Theme.text)
                            Spacer()
                            Text(formatMoney(p.net)).font(.captionB).foregroundStyle(Theme.gold)
                        }
                    }
                    .appearIn(delay: min(0.25, Double(i) * 0.03))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8).padding(.bottom, 20)
        }
        .task {
            await backend.submitScore(name: "SEN", netWorth: game.netWorth)
            await backend.loadLeaders()
        }
    }
}
