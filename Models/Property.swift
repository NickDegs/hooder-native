import Foundation
import CoreLocation

// ── Mülk kategorisi ───────────────────────────────────────────────────────────
enum PropertyCategory: String, Codable, CaseIterable {
    case building, hotel, office, retail, landmark, park, stadium

    var emoji: String {
        switch self {
        case .building: "🏢"; case .hotel: "🏨"; case .office: "🏬"
        case .retail: "🛍️"; case .landmark: "🗽"; case .park: "🌳"; case .stadium: "🏟️"
        }
    }
    var title: String {
        switch self {
        case .building: "Bina"; case .hotel: "Otel"; case .office: "Ofis"
        case .retail: "Mağaza"; case .landmark: "Simge"; case .park: "Park"; case .stadium: "Stadyum"
        }
    }
}

// ── Mülk ──────────────────────────────────────────────────────────────────────
struct Property: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var neighborhood: String
    var city: String
    var category: PropertyCategory
    var price: Double
    var incomePerDay: Double
    var prestige: Int          // 1...5
    var lat: Double
    var lng: Double
    var vipOnly: Bool = false   // yalnız VIP üyelere açık özel/erken mülk

    var roiPercent: Double { price > 0 ? incomePerDay * 365 / price * 100 : 0 }
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
}

// ── Rakip sahipler ────────────────────────────────────────────────────────────
// Bazı mülklerin "rakip" sahibi vardır (deterministik). Bunlar doğrudan ALINAMAZ;
// sahibine TEKLİF yollanır. vipOnly mülkler hariç (onlar VIP'e özel satılık).
enum Rivals {
    static let names = ["Emir Holding", "Defne Yatırım", "Kaya Group", "Marina Estates", "Atlas Realty", "Boğaz Capital", "Nova İnşaat"]
    static func owner(of p: Property) -> String? {
        guard !p.vipOnly else { return nil }
        let h = abs(p.id.hashValue)
        return (h % 100 < 35) ? names[h % names.count] : nil   // ~%35 rakip sahibi
    }
}

// vipOnly backend JSON'da olmayabilir → toleranslı decode (memberwise init korunur)
extension Property {
    enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, city, category, price, incomePerDay, prestige, lat, lng, vipOnly
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        neighborhood = try c.decode(String.self, forKey: .neighborhood)
        city = try c.decode(String.self, forKey: .city)
        category = try c.decode(PropertyCategory.self, forKey: .category)
        price = try c.decode(Double.self, forKey: .price)
        incomePerDay = try c.decode(Double.self, forKey: .incomePerDay)
        prestige = try c.decode(Int.self, forKey: .prestige)
        lat = try c.decode(Double.self, forKey: .lat)
        lng = try c.decode(Double.self, forKey: .lng)
        vipOnly = try c.decodeIfPresent(Bool.self, forKey: .vipOnly) ?? false
    }
}
