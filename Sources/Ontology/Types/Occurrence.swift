import Foundation

/// An atomic space-time fact: a single specific time, place, and description.
/// Replaces the concrete (instantiated) `Event`. Never carries a recurrence rule.
public struct Occurrence: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    public var startDate: DateTime?
    public var endDate: DateTime?
    public var place: Place?
    /// Back-reference to the Plan that generated this occurrence, if any.
    public var plan: HolonRef?

    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        startDate: DateTime? = nil,
        endDate: DateTime? = nil,
        place: Place? = nil,
        plan: HolonRef? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.place = place
        self.plan = plan
    }
}

extension Occurrence: SchemaEntityReference {
    public static var taxon: Taxon { .occurrence }
}

extension Occurrence: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, description, startDate, endDate, place, plan
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        if encoder.codingPath.isEmpty {
            try container.encode(schema.org, forKey: .context)
        }
        try container.encode(String(describing: Self.self), forKey: .type)
        try container.encodeIfPresent(identifier, forKey: .id)
        try container.encodeIfPresent(name, forKey: .attribute(.name))
        try container.encodeIfPresent(description, forKey: .attribute(.description))
        try container.encodeIfPresent(startDate, forKey: .attribute(.startDate))
        try container.encodeIfPresent(endDate, forKey: .attribute(.endDate))
        try container.encodeIfPresent(place, forKey: .attribute(.place))
        try container.encodeIfPresent(plan, forKey: .attribute(.plan))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        identifier = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        startDate = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.startDate))
        endDate = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.endDate))
        place = try container.decodeIfPresent(Place.self, forKey: .attribute(.place))
        plan = try container.decodeIfPresent(HolonRef.self, forKey: .attribute(.plan))
    }
}

extension Occurrence: Entity {}
