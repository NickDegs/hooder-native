import SwiftUI

// ── Tema: renkler, ölçü, tipografi, HAREKET eğrileri ──────────────────────────
// iOS 26 + Swift 6. Tüm "ultra yumuşak" his buradaki spring eğrilerinden gelir.
enum Theme {
    // Renkler (koyu, premium)
    static let bg        = Color(red: 0.02, green: 0.03, blue: 0.06)
    static let text      = Color.white
    static let textSub   = Color.white.opacity(0.72)
    static let textMuted = Color.white.opacity(0.45)
    static let gold      = Color(red: 1.0,  green: 0.77, blue: 0.20)
    static let green     = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let primary   = Color(red: 0.20, green: 0.58, blue: 1.0)
    static let stroke    = Color.white.opacity(0.18)

    // Ölçü
    static let rSm: CGFloat = 12
    static let rMd: CGFloat = 16
    static let rLg: CGFloat = 22
    static let rXl: CGFloat = 28
}

// ── HAREKET: tek yerden, ultra yumuşak (SwiftUI spring) ───────────────────────
enum Motion {
    /// Genel yumuşak geçiş (ekran/panel)
    static let smooth = Animation.smooth(duration: 0.5, extraBounce: 0.0)
    /// Hafif yaylı oturma (kart belirme)
    static let glass  = Animation.spring(response: 0.55, dampingFraction: 0.82)
    /// Buton basışı — hızlı, canlı
    static let press  = Animation.spring(response: 0.26, dampingFraction: 0.62)
    /// Snappy (sekme/HUD)
    static let snappy = Animation.snappy(duration: 0.34, extraBounce: 0.08)
}

// ── Tipografi kısayolları ─────────────────────────────────────────────────────
extension Font {
    static let hDisplay = Font.system(size: 34, weight: .heavy, design: .rounded)
    static let h2       = Font.system(size: 22, weight: .heavy, design: .rounded)
    static let h3       = Font.system(size: 18, weight: .bold,  design: .rounded)
    static let bodyB    = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let captionB = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let label    = Font.system(size: 10, weight: .bold, design: .rounded)
}

// ── Para biçimi ───────────────────────────────────────────────────────────────
func formatMoney(_ v: Double) -> String {
    let a = abs(v)
    switch a {
    case 1_000_000_000...: return String(format: "$%.1fB", v / 1_000_000_000)
    case 1_000_000...:     return String(format: "$%.1fM", v / 1_000_000)
    case 1_000...:         return String(format: "$%.0fK", v / 1_000)
    default:               return String(format: "$%.0f", v)
    }
}
