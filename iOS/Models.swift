import Foundation
import CoreLocation

struct Property: Identifiable, Codable, Hashable {
    let id: String
    let address: String
    let latitude: Double
    let longitude: Double
    let price: Double?
    let priceType: String
    let status: String
    let bedrooms: Double?
    let bathrooms: Double?
    let squareFootage: Double?
    let lastSalePrice: Double?
    let lastSaleDate: String?
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var formattedPrice: String {
        guard let price else { return "No value available" }
        return price.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

struct PropertiesResponse: Decodable { let properties: [Property] }
struct EstimateResponse: Decodable { let price: Double?; let priceRangeLow: Double?; let priceRangeHigh: Double? }
