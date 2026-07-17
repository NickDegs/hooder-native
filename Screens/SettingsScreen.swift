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
                UsernameCard(game: game)

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

                ReferralCard(game: game)

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

// ── Davet (referral) kartı — kendi kodun + paylaş + kod gir ────────────────────
private struct ReferralCard: View {
    var game: GameState
    @State private var info: ReferralInfo?
    @State private var entry = ""
    @State private var msg: String?
    @State private var msgOK = false
    @State private var busy = false
    @State private var l10n = L10n.shared

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(l10n.t("referral_title"), systemImage: "gift.fill")
                    .font(.bodyB).foregroundStyle(Theme.gold)
                Text(l10n.t("referral_sub"))
                    .font(.captionB).foregroundStyle(Theme.textSub)

                if let info, let code = info.code {
                    HStack {
                        Text(code).font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.text).tracking(3)
                        Spacer()
                        ShareLink(item: shareText(code)) {
                            Label(l10n.t("referral_share"), systemImage: "square.and.arrow.up")
                                .font(.captionB).foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Theme.primary, in: Capsule())
                        }
                    }
                    .padding(.vertical, 2)

                    if info.invited > 0 {
                        Text(String(format: l10n.t("referral_count"), info.invited, formatMoney(info.earned)))
                            .font(.captionB).foregroundStyle(Theme.green)
                    }

                    if !info.used_code {
                        HStack(spacing: 8) {
                            TextField(l10n.t("referral_enter_ph"), text: $entry)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.bodyB).foregroundStyle(Theme.text)
                                .padding(.horizontal, 12).frame(height: 44)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                            GlassButton(tint: Theme.green, action: redeem) { Text(l10n.t("confirm")) }
                        }
                    }
                }
                if let msg {
                    Text(msg).font(.captionB)
                        .foregroundStyle(msgOK ? Theme.green : Color(red: 0.9, green: 0.4, blue: 0.4))
                }
            }
        }
        .task { info = await BackendService.shared.referralInfo() }
    }

    private func shareText(_ code: String) -> String {
        l10n.t("referral_share_msg").replacingOccurrences(of: "%CODE%", with: code)
    }

    private func redeem() {
        let code = entry.trimmingCharacters(in: .whitespaces).uppercased()
        guard code.count >= 4, !busy else { return }
        busy = true
        Task {
            let r = await BackendService.shared.redeemReferral(code: code)
            await MainActor.run {
                busy = false
                if r.ok {
                    msgOK = true
                    msg = String(format: l10n.t("referral_ok"), formatMoney(r.reward))
                    game.cash += r.reward                 // anında yansıt (sunucu zaten ekledi)
                    entry = ""
                    Task { info = await BackendService.shared.referralInfo() }
                } else {
                    msgOK = false
                    msg = l10n.t("referral_err")
                }
            }
        }
    }
}
