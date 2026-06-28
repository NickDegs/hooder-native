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

    var roiPercent: Double { price > 0 ? incomePerDay * 365 / price * 100 : 0 }
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
}
