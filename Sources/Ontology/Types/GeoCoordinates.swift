import CoreLocation
import Foundation

/// Geographic coordinates of a place or event following Schema.org ontology
public struct GeoCoordinates: Codable, Hashable, Sendable {
    /// The latitude of a location (WGS 84)
    public var latitude: Double

    /// The longitude of a location (WGS 84)
    public var longitude: Double

    /// The elevation of a location (WGS 84) in meters
    public var elevation: Double?

    /// ICLLocationCoordinate2D  with latitude and longitude
    public var coordinates: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    /// Initialize GeoCoordinates with latitude and longitude
    public init(latitude: Double, longitude: Double, elevation: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
    }

    /// Initialize GeoCoordinates from a CLLocation
    public init(_ location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.elevation = location.altitude
    }
}

//    https://developer.apple.com/documentation/mapkit/unified-map-urls

public extension GeoCoordinates {
    var uri: URL {
        var cp = URLComponents()
        cp.scheme = "maps"
        // frame, or place for placard
        cp.path = "frame" // or "place"
        cp.queryItems = [
            .init(name: "center", value: "\(latitude),\(longitude)")
        ]
        return cp.url!
    }
    
    var url: URL {
        var cp = URLComponents(string:"https://maps.apple.com")!
        cp.path = "frame" // or "place"
        cp.queryItems = [
            .init(name: "center", value: "\(latitude),\(longitude)")
        ]
        return cp.url!
    }
}
