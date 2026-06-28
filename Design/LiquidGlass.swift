import SwiftUI

// ── iOS 26 LIQUID GLASS + "MERCEK YANMASI" (specular sweep) ────────────────────
// İki katman:
//  1) Gerçek Liquid Glass yüzeyi (iOS 26 `.glassEffect`); eski iOS'ta materyal fallback.
//  2) Üstte yüzeyde gezen parlak kırılma çizgisi = "mercek yanması" (SpecularSweep).
//     TimelineView(.animation) ile kare-senkron → ULTRA pürüzsüz, takılmasız.

struct LiquidGlass: ViewModifier {
    var cornerRadius: CGFloat = Theme.rLg
    var tint: Color = .clear
    var interactive: Bool = true
    var sweep: Bool = true     // mercek yanması — uzun listelerde kapat (perf)

    func body(content: Content) -> some View {
        content
            .background {
                if #available(iOS 26.0, *) {
                    let base = Glass.regular.tint(tint.opacity(tint == .clear ? 0 : 0.18))
                    Color.clear
                        .glassEffect(interactive ? base.interactive() : base,
                                     in: .rect(cornerRadius: cornerRadius))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tint.opacity(tint == .clear ? 0 : 0.16))
                        )
                }
            }
            .overlay { if sweep { SpecularSweep(cornerRadius: cornerRadius) } }   // ← mercek yanması
            .overlay {
                // Cam üst kenar specular highlight (parlak ince çizgi)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.08)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.6)
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

// ── Mercek yanması: yüzeyde diyagonal geçen parlak kırılma süpürmesi ───────────
struct SpecularSweep: View {
    var cornerRadius: CGFloat = Theme.rLg
    var period: Double = 6.5          // tam tur süresi (sn)
    var sweep: Double  = 0.16         // parlak bandın yarı genişliği (0..1)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            // -sweep..1+sweep arası ileri-geri yumuşak (ease) faz
            let raw = (t.truncatingRemainder(dividingBy: period)) / period   // 0..1
            let eased = 0.5 - 0.5 * cos(raw * 2 * .pi)                        // 0..1..0 yumuşak
            let p = -sweep + eased * (1 + 2 * sweep)
            let lo = max(0, p - sweep), hi = min(1, p + sweep)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.0),  location: lo),
                    .init(color: .white.opacity(0.30), location: max(lo, min(hi, p))),
                    .init(color: .white.opacity(0.0),  location: hi),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .opacity(0.9)
            .allowsHitTesting(false)
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

extension View {
    /// Liquid Glass yüzeyi + (opsiyonel) mercek yanması tek satırda.
    func liquidGlass(cornerRadius: CGFloat = Theme.rLg, tint: Color = .clear,
                     interactive: Bool = true, sweep: Bool = true) -> some View {
        modifier(LiquidGlass(cornerRadius: cornerRadius, tint: tint, interactive: interactive, sweep: sweep))
    }
}
