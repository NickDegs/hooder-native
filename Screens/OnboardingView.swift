import SwiftUI

// ── İLK AÇILIŞ KARŞILAMA / ONBOARDING ─────────────────────────────────────────
// Yeni oyuncu uygulamayı ilk kez açtığında görür (UserDefaults "hooder_onboarded").
// Amaç: huniyi kapatmak — oyuncu haritaya düşmeden önce NE oynadığını 10 saniyede
// anlasın, sahiplik hissi + net bir ilk hedef alsın, ardından "başla" ile haritaya.
// Son sayfada bildirim izni istenir (yerel retention bildirimleri için).
struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0
    private let last = 3

    private struct Slide {
        let icon: String
        let tint: Color
        let titleKey: String
        let bodyKey: String
    }
    private let slides: [Slide] = [
        .init(icon: "globe.europe.africa.fill", tint: Theme.gold,
              titleKey: "ob_1_title", bodyKey: "ob_1_body"),
        .init(icon: "building.2.fill", tint: Theme.primary,
              titleKey: "ob_2_title", bodyKey: "ob_2_body"),
        .init(icon: "dollarsign.circle.fill", tint: Theme.green,
              titleKey: "ob_3_title", bodyKey: "ob_3_body"),
        .init(icon: "bell.badge.fill", tint: Theme.gold,
              titleKey: "ob_4_title", bodyKey: "ob_4_body"),
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Atla (son sayfa hariç)
                HStack {
                    Spacer()
                    if page < last {
                        Button(t("ob_skip")) { finish() }
                            .font(.bodyB).foregroundStyle(Theme.textMuted)
                            .padding(.horizontal, 20).padding(.top, 10)
                    }
                }
                .frame(height: 40)

                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { i, s in
                        slideView(s, isNotify: i == last).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(Motion.smooth, value: page)

                // Sayfa noktaları
                HStack(spacing: 8) {
                    ForEach(0...last, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Theme.gold : Color.white.opacity(0.22))
                            .frame(width: i == page ? 22 : 7, height: 7)
                            .animation(Motion.snappy, value: page)
                    }
                }
                .padding(.bottom, 20)

                // Ana buton
                Button {
                    if page < last { withAnimation(Motion.smooth) { page += 1 } }
                    else { requestNotifyThenFinish() }
                } label: {
                    Text(page < last ? t("ob_next") : t("ob_start"))
                        .font(.h3).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Theme.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, page == last ? 12 : 34)

                // Son sayfada: bildirim izni açıklaması + "şimdi değil"
                if page == last {
                    Button(t("ob_notify_later")) { finish() }
                        .font(.bodyB).foregroundStyle(Theme.textMuted)
                        .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func slideView(_ s: Slide, isNotify: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(s.tint.opacity(0.14)).frame(width: 168, height: 168)
                Circle().stroke(s.tint.opacity(0.35), lineWidth: 1).frame(width: 168, height: 168)
                Image(systemName: s.icon)
                    .font(.system(size: 74, weight: .bold))
                    .foregroundStyle(s.tint)
                    .shadow(color: s.tint.opacity(0.4), radius: 18)
            }
            .padding(.bottom, 44)

            Text(t(s.titleKey))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Text(t(s.bodyKey))
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSub)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 38)
                .padding(.top, 14)

            Spacer()
        }
    }

    private func requestNotifyThenFinish() {
        Task {
            await NotificationManager.shared.requestAuthorization()
            finish()
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hooder_onboarded")
        onFinish()
    }
}
