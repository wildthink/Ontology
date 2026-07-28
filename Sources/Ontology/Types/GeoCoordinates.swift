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
