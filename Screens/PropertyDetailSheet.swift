import SwiftUI

// ── Mülk detay sheet'i — cam, sahip bilgisi, satın alma / teklif yollama ──────
struct PropertyDetailSheet: View {
    let property: Property
    var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false
    @State private var offering = false
    @State private var offerAmount = ""
    @State private var msg: String?

    private var rival: String? { Rivals.owner(of: property) }

    var body: some View {
        let owned = game.isOwned(property.id)
        let price = game.livePrice(property)
        let canAfford = game.cash >= price

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(property.category.emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(property.name).font(.h2).foregroundStyle(Theme.text)
                        if property.vipOnly {
                            Label("VIP", systemImage: "crown.fill")
                                .font(.system(size: 9, weight: .heavy)).foregroundStyle(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.gold, in: Capsule())
                        }
                    }
                    Text("\(property.neighborhood) · \(property.city)")
                        .font(.captionB).foregroundStyle(Theme.textSub)
                }
                Spacer()
            }

            // Sahip bilgisi
            ownerRow(owned: owned)

            // Prestij
            HStack(spacing: 3) {
                ForEach(0..<5) { i in
                    Image(systemName: i < property.prestige ? "star.fill" : "star")
                        .font(.system(size: 12)).foregroundStyle(Theme.gold.opacity(i < property.prestige ? 1 : 0.3))
                }
            }

            HStack(spacing: 10) {
                stat(L10n.shared.t("price"), formatMoney(price), Theme.text)
                stat(L10n.shared.t("income_day"), "+\(formatMoney(property.incomePerDay))", Theme.green)
                stat("ROI", String(format: "%.1f%%", property.roiPercent), Theme.gold)
            }

            Spacer()

            actionArea(owned: owned, price: price, canAfford: canAfford)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .top) {
            if let msg { Text(msg).font(.bodyB).foregroundStyle(Theme.text)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .liquidGlass(cornerRadius: 99, interactive: false).padding(.top, 8) }
        }
        .alert(L10n.shared.t("send_offer"), isPresented: $offering) {
            TextField(L10n.shared.t("price"), text: $offerAmount).keyboardType(.numberPad)
            Button(L10n.shared.t("cancel"), role: .cancel) {}
            Button("✓") { submitOffer() }
        } message: {
            Text("\(rival ?? "") — min \(formatMoney(price * 1.15))")
        }
    }

    @ViewBuilder private func ownerRow(owned: Bool) -> some View {
        let (icon, text, color): (String, String, Color) =
            owned ? ("person.fill", "\(L10n.shared.t("owner")): \(L10n.shared.t("you"))", Theme.green)
            : rival != nil ? ("building.2.fill", "\(L10n.shared.t("owner")): \(rival!)", Theme.gold)
            : ("checkmark.circle.fill", L10n.shared.t("available"), Theme.primary)
        Label(text, systemImage: icon)
            .font(.captionB).foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: Theme.rMd, interactive: false)
    }

    @ViewBuilder private func actionArea(owned: Bool, price: Double, canAfford: Bool) -> some View {
        if owned {
            Label(L10n.shared.t("owned_msg"), systemImage: "checkmark.seal.fill")
                .font(.bodyB).foregroundStyle(Theme.green)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.green.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.rLg))
        } else if rival != nil {
            // Rakip elinde → teklif yolla
            GlassButton(tint: Theme.gold, action: {
                offerAmount = String(Int(price * 1.2)); offering = true
            }) { Label(L10n.shared.t("send_offer"), systemImage: "hands.sparkles.fill") }
        } else if property.vipOnly && !game.isVIP {
            Label("\(L10n.shared.t("vip_title")) — \(L10n.shared.t("vip_perk_exclusive"))", systemImage: "crown.fill")
                .font(.bodyB).foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.rLg))
        } else if confirming {
            HStack(spacing: 10) {
                GlassButton(tint: .gray, action: { withAnimation(Motion.snappy) { confirming = false } }) { Text(L10n.shared.t("cancel")) }
                GlassButton(tint: Theme.green, action: {
                    if game.buy(property) { dismiss() }
                }) { Text("\(L10n.shared.t("confirm")) — \(formatMoney(price))") }
            }
        } else {
            GlassButton(tint: canAfford ? Theme.primary : .gray, action: {
                withAnimation(Motion.snappy) { confirming = true }
            }) { Text(canAfford ? "\(L10n.shared.t("buy")) — \(formatMoney(price))" : L10n.shared.t("low_funds")) }
            .disabled(!canAfford)
        }
    }

    private func submitOffer() {
        guard let amt = Double(offerAmount.filter(\.isNumber)) else { return }
        switch game.makeOffer(property, amount: amt) {
        case 1: showMsg("🎉 \(L10n.shared.t("offer_accepted"))"); DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { dismiss() }
        case 2: showMsg("🙅 \(L10n.shared.t("offer_rejected"))")
        default: showMsg(L10n.shared.t("low_funds"))
        }
    }
    private func showMsg(_ s: String) {
        withAnimation(Motion.glass) { msg = s }
        Task { try? await Task.sleep(for: .seconds(2)); withAnimation { msg = nil } }
    }

    private func stat(_ t: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(t).font(.label).foregroundStyle(Theme.textMuted)
            Text(v).font(.bodyB).foregroundStyle(c)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .liquidGlass(cornerRadius: Theme.rMd, interactive: false)
    }
}
