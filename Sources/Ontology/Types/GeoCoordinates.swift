import Foundation

/// Geographic coordinates of a place following Schema.org GeoCoordinates.
public struct GeoCoordinates: Hashable, Sendable {
    /// The latitude of a location (WGS 84).
    public var latitude: Double

    /// The longitude of a location (WGS 84).
    public var longitude: Double

    /// The elevation of a location (WGS 84) in meters.
    public var elevation: Double?

    public init(latitude: Double, longitude: Double, elevation: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
    }
}

extension GeoCoordinates: Codable {
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude, elevation
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        if encoder.codingPath.isEmpty {
            try container.encode(schema.org, forKey: .context)
        }
        try container.encode(String(describing: Self.self), forKey: .type)
        try container.encode(latitude, forKey: .attribute(.latitude))
        try container.encode(longitude, forKey: .attribute(.longitude))
        try container.encodeIfPresent(elevation, forKey: .attribute(.elevation))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        latitude = try container.decode(Double.self, forKey: .attribute(.latitude))
        longitude = try container.decode(Double.self, forKey: .attribute(.longitude))
        elevation = try container.decodeIfPresent(Double.self, forKey: .attribute(.elevation))
    }
}

// https://developer.apple.com/documentation/mapkit/unified-map-urls
public extension GeoCoordinates {
    var uri: URL {
        var cp = URLComponents()
        cp.scheme = "maps"
        cp.path = "frame"
        cp.queryItems = [.init(name: "center", value: "\(latitude),\(longitude)")]
        return cp.url!
    }

    var url: URL {
        var cp = URLComponents(string: "https://maps.apple.com")!
        cp.path = "frame"
        cp.queryItems = [.init(name: "center", value: "\(latitude),\(longitude)")]
        return cp.url!
    }
}
