#if canImport(CoreLocation)
import CoreLocation
import Ontology

extension GeoCoordinates {
    public var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(_ location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            elevation: location.altitude
        )
    }
}
#endif
