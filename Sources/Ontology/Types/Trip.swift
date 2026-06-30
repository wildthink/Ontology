import Foundation

/// Represents a trip or journey, corresponding to Schema.org's Trip type (https://schema.org/Trip).
/// An itinerary of visits to one or more places.
public struct Trip: Hashable, Sendable {
    /// Unique identifier for the trip.
    public var identifier: String?

    /// The name of the trip.
    public var name: String?

    /// A description of the trip.
    public var description: String?

    /// The expected arrival time.
    public var arrivalTime: DateTime?

    /// The expected departure time.
    public var departureTime: DateTime?

    /// Destination(s) (Place) that make up the trip.
    /// For a trip where destination order is important, this array preserves the order.
    public var itinerary: [Place]?

    /// The location of origin of the trip, prior to any destination(s).
    public var tripOrigin: Place?

    // Note: Properties like 'offers', 'provider', 'subTrip', 'partOfTrip' are omitted for simplicity
    // but could be added based on schema.org/Trip definition.

    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        arrivalTime: DateTime? = nil,
        departureTime: DateTime? = nil,
        itinerary: [Place]? = nil,
        tripOrigin: Place? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.itinerary = itinerary
        self.tripOrigin = tripOrigin
    }
}

extension Trip: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, description, arrivalTime, departureTime, itinerary, tripOrigin
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        // Encode @context if we're at the root level
        if encoder.codingPath.isEmpty {
            try container.encode(schema.org, forKey: .context)
        }

        // Encode @type
        try container.encode(String(describing: Self.self), forKey: .type)

        // Encode @id
        try container.encodeIfPresent(identifier, forKey: .id)

        // Encode properties
        try container.encodeIfPresent(name, forKey: .attribute(.name))
        try container.encodeIfPresent(description, forKey: .attribute(.description))
        try container.encodeIfPresent(arrivalTime, forKey: .attribute(.arrivalTime))
        try container.encodeIfPresent(departureTime, forKey: .attribute(.departureTime))
        try container.encodeIfPresent(itinerary, forKey: .attribute(.itinerary))
        try container.encodeIfPresent(tripOrigin, forKey: .attribute(.tripOrigin))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        // Verify type is correct
        let describedType = String(describing: Self.self)
        let decodedType = try container.decode(String.self, forKey: .type)
        guard decodedType == describedType else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected type to be '\(describedType)', but found \(decodedType)"
            )
        }

        // Decode @id
        identifier = try container.decodeIfPresent(String.self, forKey: .id)

        // Decode properties
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        arrivalTime = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.arrivalTime))
        departureTime = try container.decodeIfPresent(
            DateTime.self, forKey: .attribute(.departureTime))
        itinerary = try container.decodeIfPresent([Place].self, forKey: .attribute(.itinerary))
        tripOrigin = try container.decodeIfPresent(Place.self, forKey: .attribute(.tripOrigin))
    }
}

