import Foundation
import Observation

// ── Mülk beslemesi ────────────────────────────────────────────────────────────
// Harita döşemeleri OFFLINE; mülkler (pin'ler) CANLI. Bu servis mülkleri tutar:
//  • Açılışta tohum (seed) mülklerle başlar (internetsiz de dolu görünür).
//  • Sunucu ucu verilirse periyodik canlı çeker; hata olursa son hâli korur.
@MainActor
@Observable
final class PropertyFeed {
    static let shared = PropertyFeed()

    private(set) var all: [Property] = PropertyFeed.seed()
    var endpoint: URL?
    private var timer: Timer?

    /// Gerçek (tilequery) mülkleri listeye kat — id'ye göre tekilleştirir.
    func ingest(_ props: [Property]) {
        guard !props.isEmpty else { return }
        var seen = Set(all.map(\.id))
        var merged = all
        for p in props where !seen.contains(p.id) { merged.append(p); seen.insert(p.id) }
        all = merged
    }

    func start(interval: TimeInterval = 30) {
        guard endpoint != nil else { return }
        fetch()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetch() }
        }
    }
    func stop() { timer?.invalidate(); timer = nil }

    private func fetch() {
        guard let endpoint else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: endpoint)
                let fresh = try JSONDecoder().decode([Property].self, from: data)
                if !fresh.isEmpty { all = fresh }      // başarı → güncelle
            } catch { /* internet yok → son hâli koru */ }
        }
    }

    // İstanbul çevresi örnek tohum mülkleri
    static func seed() -> [Property] {
        let base = (lat: 41.0082, lng: 28.9784)
        let names: [(String, PropertyCategory, Double, Int)] = [
            ("Galata Rezidans", .building, 18_500_000, 3),
            ("Karaköy Otel",    .hotel,    92_000_000, 5),
            ("Levent Plaza",    .office,   65_000_000, 4),
            ("Beyoğlu Pasaj",   .retail,   24_000_000, 3),
            ("Kız Kulesi Manzara", .landmark, 140_000_000, 5),
            ("Maçka Park Evleri",  .park,   31_000_000, 2),
            ("Vodafone Park Loca", .stadium, 110_000_000, 4),
            ("Cihangir Apartman",  .building, 9_500_000, 1),
            ("Nişantaşı Butik",    .retail, 28_000_000, 3),
            ("Şişli Ofis Kulesi",  .office, 54_000_000, 4),
        ]
        var list = names.enumerated().map { i, n in
            let dl = Double(i)
            let lat = base.lat + sin(dl) * 0.012 + dl * 0.0015
            let lng = base.lng + cos(dl) * 0.014 - dl * 0.0011
            return Property(
                id: "seed_\(i)", name: n.0,
                neighborhood: ["Galata","Karaköy","Levent","Beyoğlu","Üsküdar","Maçka","Beşiktaş","Cihangir","Nişantaşı","Şişli"][i],
                city: "İstanbul", category: n.1, price: n.2,
                incomePerDay: (n.2 * 0.0009).rounded(), prestige: n.3, lat: lat, lng: lng)
        }
        // ── VIP'e özel prestijli mülkler (yalnız VIP üyeler alabilir) ──────────
        let vip: [(String, PropertyCategory, Double, Int, String, Double, Double)] = [
            ("Boğaz Yalısı 👑", .landmark, 480_000_000, 5, "Bebek", 41.0776, 29.0434),
            ("Çamlıca Kulesi Loca 👑", .landmark, 320_000_000, 5, "Üsküdar", 41.0276, 29.0686),
            ("Maslak 42 Penthouse 👑", .office, 260_000_000, 5, "Maslak", 41.1110, 29.0190),
        ]
        list += vip.map { v in
            Property(id: "vip_\(v.0.hashValue)", name: v.0, neighborhood: v.4, city: "İstanbul",
                     category: v.1, price: v.2, incomePerDay: (v.2 * 0.0011).rounded(),
                     prestige: v.3, lat: v.5, lng: v.6, vipOnly: true)
        }
        return list
    }
}
