#if canImport(MapKit)
import MapKit
import Ontology

extension Trip {
    public init(_ response: MKDirections.Response) {
        let steps = response.routes.first?.steps.compactMap { Place($0) } ?? []
        self.init(
            name: response.routes.first?.name,
            itinerary: steps + [Place(response.destination)],
            tripOrigin: Place(response.source)
        )
    }

    public init(_ response: MKDirections.ETAResponse) {
        self.init(
            arrivalTime: DateTime(response.expectedArrivalDate),
            departureTime: DateTime(response.expectedDepartureDate),
            itinerary: [Place(response.destination)],
            tripOrigin: Place(response.source)
        )
    }
}
#endif
