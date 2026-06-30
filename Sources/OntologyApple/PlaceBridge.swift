#if canImport(MapKit)
import MapKit
import Ontology

extension Place {
    public var clCoordinate: CLLocationCoordinate2D? {
        geo?.clCoordinate
    }

    public func coordinateRegion(radius: Double) -> MKCoordinateRegion? {
        guard let coord = geo?.clCoordinate else { return nil }
        return MKCoordinateRegion(
            center: coord,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
    }

    public init(_ placemark: MKPlacemark) {
        self.init(
            name: placemark.name,
            address: placemark.postalAddress.map { PostalAddress($0) },
            geo: placemark.location.map { GeoCoordinates($0) }
        )
    }

    public init(_ mapItem: MKMapItem) {
        self.init(mapItem.placemark)
        self.telephone = mapItem.phoneNumber
        self.url = mapItem.url
    }

    public init?(_ step: MKRoute.Step) {
        let count = step.polyline.pointCount
        guard count > 0 else { return nil }
        let coord = step.polyline.points()[count - 1].coordinate
        self.init(
            description: step.instructions,
            geo: GeoCoordinates(latitude: coord.latitude, longitude: coord.longitude)
        )
    }
}
#endif
