import SwiftUI

// ── Ayarlar: offline harita bilgisi, oyun sıfırlama, hakkında ─────────────────
struct SettingsScreen: View {
    var game: GameState
    @State private var confirmReset = false
    @State private var confirmCache = false
    @State private var cacheCount = 0
    @State private var cacheMB = 0.0
    @State private var cacheMsg: String?
    @State private var l10n = L10n.shared

    private func refreshCacheInfo() {
        Task {
            let info = await PropertyService.shared.cacheInfo()
            await MainActor.run { cacheCount = info.count; cacheMB = info.approxMB }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Dil seçici (16 dil) — anında uygulanır
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(l10n.t("language"), systemImage: "globe").font(.bodyB).foregroundStyle(Theme.text)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(L10n.languages, id: \.self) { code in
                                    let on = l10n.lang == code
                                    Button {
                                        withAnimation(Motion.snappy) { l10n.lang = code }
                                    } label: {
                                        Text(L10n.names[code] ?? code).font(.captionB)
                                            .foregroundStyle(on ? Theme.primary : Theme.textSub)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(on ? Theme.primary.opacity(0.16) : .white.opacity(0.06), in: Capsule())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Offline Uydu Harita", systemImage: "square.and.arrow.down.fill")
                            .font(.bodyB).foregroundStyle(Theme.text)
                        Text("Harita döşemeleri cihaza indirildi; internet olmadan da açılır. Sadece mülk etiketleri canlı güncellenir.")
                            .font(.captionB).foregroundStyle(Theme.textSub)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Liquid Glass", systemImage: "sparkles")
                            .font(.bodyB).foregroundStyle(Theme.text)
                        Text("iOS 26 cam yüzeyler + mercek yanması + ultra yumuşak animasyonlar aktif.")
                            .font(.captionB).foregroundStyle(Theme.textSub)
                    }
                }

                // ── Önbellek (indirilen mülk verisi) — temizle, yer aç ───────────
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Önbellek (İndirilen Mülkler)", systemImage: "internaldrive.fill")
                            .font(.bodyB).foregroundStyle(Theme.text)
                        Text("Gezdiğin şehirlerin mülkleri cihazda saklanır → tekrar açtığında anında gelir. Şu an: \(cacheCount) mülk · ~\(String(format: "%.1f", cacheMB)) MB. Temizlersen yer açılır; gezdikçe yeniden iner.")
                            .font(.captionB).foregroundStyle(Theme.textSub)
                        if let cacheMsg {
                            Text(cacheMsg).font(.captionB).foregroundStyle(Theme.green)
                        }
                        if confirmCache {
                            HStack(spacing: 10) {
                                GlassButton(tint: .gray, action: { withAnimation(Motion.snappy) { confirmCache = false } }) { Text("Vazgeç") }
                                GlassButton(tint: Color(red: 0.9, green: 0.6, blue: 0.2), action: {
                                    Task {
                                        let n = await PropertyService.shared.clearCache()
                                        await MainActor.run {
                                            cacheMsg = "✓ \(n) mülk temizlendi"
                                            withAnimation(Motion.snappy) { confirmCache = false }
                                            refreshCacheInfo()
                                        }
                                    }
                                }) { Text("Evet, temizle") }
                            }
                        } else {
                            GlassButton(tint: Color(red: 0.9, green: 0.6, blue: 0.2), action: {
                                cacheMsg = nil; withAnimation(Motion.snappy) { confirmCache = true }
                            }) { Text("Önbelleği Temizle") }
                        }
                    }
                }

                if confirmReset {
                    HStack(spacing: 10) {
                        GlassButton(tint: .gray, action: { withAnimation(Motion.snappy) { confirmReset = false } }) { Text("Vazgeç") }
                        GlassButton(tint: Theme.green, action: {
                            game.reset(); withAnimation(Motion.snappy) { confirmReset = false }
                        }) { Text("Evet, sıfırla") }
                    }.padding(.horizontal, 14)
                } else {
                    GlassButton(tint: Color(red: 0.9, green: 0.25, blue: 0.25), action: {
                        withAnimation(Motion.snappy) { confirmReset = true }
                    }) { Text(l10n.t("reset_game")) }
                        .padding(.horizontal, 14)
                }

                Text("Hooder · Native (iOS 26 · Swift 6)")
                    .font(.label).foregroundStyle(Theme.textMuted).padding(.top, 8)
            }
            .padding(.horizontal, 14).padding(.vertical, 8).padding(.bottom, 20)
        }
        .onAppear { refreshCacheInfo() }
    }
}
