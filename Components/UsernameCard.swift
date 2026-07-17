import SwiftUI

// ── Kullanıcı adı kartı (Ayarlar) ─────────────────────────────────────────────
// Liderlik tablosunda görünen adı değiştirir. Ad SUNUCUDA doğrulanır ve saklanır
// (uzunluk/karakter/benzersizlik) → istemci sahte isim dayatamaz. Anon hesap açılışta
// "Patron_xxxxxxxx" adını alır; oyuncu buradan kendi adını seçer.
struct UsernameCard: View {
    var game: GameState

    @State private var draft = ""
    @State private var saving = false
    @State private var msg: String?
    @State private var ok = false
    @State private var l10n = L10n.shared

    private var changed: Bool {
        let t = draft.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && t != game.username
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(l10n.t("username"), systemImage: "person.text.rectangle")
                    .font(.bodyB).foregroundStyle(Theme.text)
                Text(l10n.t("username_hint"))
                    .font(.captionB).foregroundStyle(Theme.textSub)

                HStack(spacing: 8) {
                    TextField(game.username.isEmpty ? "Patron" : game.username, text: $draft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(Theme.text).font(.bodyB)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.rSm))
                        .onSubmit { save() }

                    Button {
                        save()
                    } label: {
                        if saving { ProgressView().tint(.white).scaleEffect(0.8).frame(width: 64) }
                        else { Text(l10n.t("save")).font(.bodyB).frame(width: 64) }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(changed ? Theme.primary : Theme.textMuted)
                    .padding(.vertical, 10)
                    .background((changed ? Theme.primary : Theme.textMuted).opacity(0.14), in: Capsule())
                    .disabled(!changed || saving)
                }

                if let msg {
                    Text(msg).font(.captionB)
                        .foregroundStyle(ok ? Theme.green : .red)
                        .transition(.opacity)
                }
            }
        }
        .animation(Motion.smooth, value: msg)
        .onAppear { if draft.isEmpty { draft = game.username } }
        .onChange(of: game.username) { _, new in if draft.isEmpty { draft = new } }
    }

    private func save() {
        let name = draft.trimmingCharacters(in: .whitespaces)
        guard changed, !saving else { return }
        saving = true; msg = nil
        Task {
            let err = await BackendService.shared.setUsername(name)
            await MainActor.run {
                saving = false
                switch err {
                case nil:
                    game.username = name
                    ok = true; msg = l10n.t("saved")
                case "taken":
                    ok = false; msg = l10n.t("name_taken")
                default:                       // length | charset | error
                    ok = false; msg = l10n.t("name_bad")
                }
            }
        }
    }
}
