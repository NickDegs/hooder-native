import SwiftUI

// ── Piyasa: mülk listesi + arama (satın alma PropertyRowView'da, kart-içi) ────
struct MarketScreen: View {
    var game: GameState
    var feed: PropertyFeed
    var onSelect: (Property) -> Void

    @State private var search = ""
    @State private var toast: String?
    @State private var backend = BackendService.shared
    @State private var bidTarget: Auction?
    @State private var bidAmount = ""

    private var filtered: [Property] {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        let list = q.isEmpty ? feed.all : feed.all.filter {
            $0.name.lowercased().contains(q) || $0.city.lowercased().contains(q) || $0.neighborhood.lowercased().contains(q)
        }
        return list.sorted { $0.price > $1.price }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted)
                TextField(L10n.shared.t("search_ph"), text: $search)
                    .foregroundStyle(Theme.text).font(.bodyB)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textMuted) }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .liquidGlass(cornerRadius: Theme.rMd, interactive: false)
            .padding(.horizontal, 14)

            ScrollView {
                LazyVStack(spacing: 12) {
                    // Canlı açık artırmalar (backend)
                    if !backend.auctions.isEmpty {
                        ForEach(backend.auctions) { a in
                            GlassCard(tint: Theme.gold) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("🔨 \(a.propertyName)").font(.bodyB).foregroundStyle(Theme.text)
                                        Text("\(a.bidderName ?? "Açılış"): \(formatMoney(max(a.currentBid, a.startPrice)))")
                                            .font(.captionB).foregroundStyle(Theme.textSub)
                                    }
                                    Spacer()
                                    Button {
                                        bidAmount = String(Int(max(a.currentBid, a.startPrice) * 1.1))
                                        bidTarget = a
                                    } label: {
                                        Text("Teklif").font(.captionB).foregroundStyle(.black)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(Theme.gold, in: Capsule())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { i, p in
                        PropertyRowView(property: p, game: game, onSelect: onSelect, onToast: showToast)
                            .appearIn(delay: min(0.25, Double(i) * 0.02))
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 20)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast { ToastView(text: toast).padding(.bottom, 100) }
        }
        .task { await backend.loadAuctions() }
        .alert("Teklif ver", isPresented: Binding(get: { bidTarget != nil }, set: { if !$0 { bidTarget = nil } })) {
            TextField("Tutar", text: $bidAmount).keyboardType(.numberPad)
            Button("İptal", role: .cancel) { bidTarget = nil }
            Button("Gönder") {
                if let a = bidTarget, let amt = Double(bidAmount.filter(\.isNumber)) {
                    Task {
                        let ok = await backend.bid(auctionId: a.id, amount: amt)
                        showToast(ok ? "Teklif verildi 🔨" : "Teklif başarısız")
                    }
                }
                bidTarget = nil
            }
        } message: {
            Text(bidTarget.map { "\($0.propertyName) — min \(formatMoney(max($0.currentBid, $0.startPrice) * 1.1))" } ?? "")
        }
    }

    private func showToast(_ s: String) {
        withAnimation(Motion.glass) { toast = s }
        Task { try? await Task.sleep(for: .seconds(2.2)); withAnimation { toast = nil } }
    }
}

struct ToastView: View {
    let text: String
    var body: some View {
        Text(text).font(.bodyB).foregroundStyle(Theme.text)
            .padding(.horizontal, 20).padding(.vertical, 11)
            .liquidGlass(cornerRadius: 99, interactive: false)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// ── Alan listesi (yoğun bölgede haritadan otomatik açılır) ────────────────────
struct AreaListSheet: View {
    var game: GameState
    let properties: [Property]
    var onSelect: (Property) -> Void
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.shared.t("area_props")).font(.h3).foregroundStyle(Theme.text)
                Spacer()
                Text("\(properties.count)").font(.captionB).foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(properties.enumerated()), id: \.element.id) { i, p in
                        PropertyRowView(property: p, game: game, onSelect: onSelect, onToast: { s in
                            withAnimation(Motion.glass) { toast = s }
                            Task { try? await Task.sleep(for: .seconds(2)); withAnimation { toast = nil } }
                        })
                        .appearIn(delay: min(0.25, Double(i) * 0.02))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8).padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) { if let toast { ToastView(text: toast).padding(.bottom, 20) } }
    }
}
