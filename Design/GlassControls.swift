import SwiftUI
import UIKit

// ── Cam kart ──────────────────────────────────────────────────────────────────
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Theme.rLg
    var tint: Color = .clear
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: cornerRadius, tint: tint, interactive: false)
    }
}

// ── Cam buton — ULTRA yumuşak basış (scale + spring) ──────────────────────────
struct GlassButton<Label: View>: View {
    var tint: Color = Theme.primary
    var action: () -> Void
    @ViewBuilder var label: () -> Label
    @State private var pressed = false

    var body: some View {
        Button(action: {
            // hafif haptik + aksiyon
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        }) {
            label()
                .font(.bodyB)
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .liquidGlass(cornerRadius: 99, tint: tint)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.94 : 1)
        .animation(Motion.press, value: pressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
    }
}

// ── Belirme animasyonu: yumuşak yukarı kayma + ölçek (liquid giriş) ────────────
struct AppearIn: ViewModifier {
    var delay: Double = 0
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.98)
            .offset(y: shown ? 0 : 14)
            .blur(radius: shown ? 0 : 6)
            .onAppear {
                withAnimation(Motion.glass.delay(delay)) { shown = true }
            }
    }
}
extension View {
    func appearIn(delay: Double = 0) -> some View { modifier(AppearIn(delay: delay)) }
}
