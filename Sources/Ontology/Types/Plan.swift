import Foundation

/// An intent or template. May carry a recurrence rule and generate Occurrences.
/// Replaces the overloaded `Event` (abstract) and `PlanAction` concepts.
public struct Plan: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    public var startDate: DateTime?
    public var endDate: DateTime?
    public var location: Place?
    /// RFC 5545 RRULE string, e.g. "FREQ=WEEKLY;BYDAY=FR"
    public var rrule: String?
    public var tags: [String]?

    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        startDate: DateTime? = nil,
        endDate: DateTime? = nil,
        location: Place? = nil,
        rrule: String? = nil,
        tags: [String]? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.rrule = rrule
        self.tags = tags
    }
}

extension Plan: SchemaEntityReference {
    public static var taxon: Taxon { .plan }
}

extension Plan: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, description, startDate, endDate, location, rrule, tags
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
        try container.encodeIfPresent(location, forKey: .attribute(.location))
        try container.encodeIfPresent(rrule, forKey: .attribute(.rrule))
        try container.encodeIfPresent(tags, forKey: .attribute(.tags))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        identifier = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        startDate = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.startDate))
        endDate = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.endDate))
        location = try container.decodeIfPresent(Place.self, forKey: .attribute(.location))
        rrule = try container.decodeIfPresent(String.self, forKey: .attribute(.rrule))
        tags = try container.decodeIfPresent([String].self, forKey: .attribute(.tags))
    }
}

extension Plan: Entity {}
