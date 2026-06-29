import Foundation

// ── Ekran görüntüsü çekimi (CI simulator) için başlatma argümanları ────────────
// Normal kullanıcıyı etkilemez; yalnız `-snapTab` / `-snapLang` argümanlarıyla açılınca devreye girer.
//   xcrun simctl launch booted <bundle> -snapLang de -snapTab market
enum Snapshot {
    private static let args = ProcessInfo.processInfo.arguments

    static var active: Bool { args.contains("-snapTab") || args.contains("-snapLang") }

    static var initialTab: AppTab? {
        guard let i = args.firstIndex(of: "-snapTab"), i + 1 < args.count else { return nil }
        switch args[i + 1] {
        case "market": return .market
        case "portfolio": return .portfolio
        case "forex": return .forex
        case "store": return .store
        case "rankings": return .rankings
        case "settings": return .settings
        default: return .map
        }
    }

    @MainActor static func applyLang() {
        guard let i = args.firstIndex(of: "-snapLang"), i + 1 < args.count else { return }
        L10n.shared.lang = args[i + 1]
    }

    // Çekimde harita/liste daha dolu görünsün diye örnek başlangıç (yalnız snapshot modunda)
    @MainActor static func prime(_ game: GameState) {
        guard active else { return }
    }
}
