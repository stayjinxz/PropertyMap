import Foundation

struct PropertyAPI {
    // Change this to your deployed HTTPS backend URL (no trailing slash).
    static let baseURL = "https://propertymap-1.onrender.com"

    static func nearby(latitude: Double, longitude: Double, radius: Double, mode: String) async throws -> [Property] {
        var url = URLComponents(string: "\(baseURL)/api/properties")!
        url.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "radius", value: String(radius)),
            .init(name: "mode", value: mode)
        ]
        let (data, response) = try await URLSession.shared.data(from: url.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(PropertiesResponse.self, from: data).properties
    }

    static func estimate(address: String) async throws -> EstimateResponse {
        var url = URLComponents(string: "\(baseURL)/api/estimate")!
        url.queryItems = [.init(name: "address", value: address)]
        let (data, response) = try await URLSession.shared.data(from: url.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(EstimateResponse.self, from: data)
    }
}
