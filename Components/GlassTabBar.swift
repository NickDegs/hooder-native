import SwiftUI
import UIKit

enum AppTab: Int, CaseIterable, Identifiable {
    case map, market, portfolio, forex, store, rankings, settings
    var id: Int { rawValue }
    var titleKey: String {
        switch self { case .map: "tab_map"; case .market: "tab_market"; case .portfolio: "tab_portfolio"
                      case .forex: "tab_forex"; case .store: "tab_store"; case .rankings: "tab_rankings"; case .settings: "tab_settings" }
    }
    var icon: String {
        switch self { case .map: "map.fill"; case .market: "chart.bar.fill"; case .portfolio: "briefcase.fill"
                      case .forex: "dollarsign.arrow.circlepath"; case .store: "bag.fill"; case .rankings: "trophy.fill"; case .settings: "slider.horizontal.3" }
    }
}

// ── Cam sekme çubuğu — yumuşak seçim göstergesi (matchedGeometry) ─────────────
struct GlassTabBar: View {
    @Binding var tab: AppTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { t in
                let on = t == tab
                VStack(spacing: 3) {
                    Image(systemName: t.icon).font(.system(size: 17, weight: .semibold))
                    Text(L10n.shared.t(t.titleKey)).font(.label)
                }
                .foregroundStyle(on ? Theme.primary : Theme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if on {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.primary.opacity(0.16))
                            .matchedGeometryEffect(id: "tabsel", in: ns)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(Motion.snappy) { tab = t }
                }
            }
        }
        .padding(6)
        .liquidGlass(cornerRadius: Theme.rXl)
        .padding(.horizontal, 14)
    }
}
