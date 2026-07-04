import Foundation

/// An atomic space-time fact: a single specific time, place, and description.
/// Replaces the concrete (instantiated) `Event`. Never carries a recurrence rule.
public struct Occurrence: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    public var startDate: DateTime?
    public var endDate: DateTime?
    /// Structured location. Prefer this over a bare string when a `Place` entity exists.
    public var place: Place?
    /// Flat location string, for simple/bridged use (e.g. from EKEvent.location).
    public var location: String?
    public var url: URL?
    public var organizer: Person?
    public var attendees: [Person]?
    /// Event status (Schema.org vocabulary: EventScheduled, EventCancelled, etc.)
    public var status: String?
    /// Back-reference to the Plan that generated this occurrence, if any.
    public var plan: HolonRef?
    /// Alarms attached to this occurrence. These prompt attendees but do not gate plan completion.
    public var alarms: [Alarm]?
    /// External and proxy identifiers for cross-system matching.
    public var handles: [Handle]?

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        startDate: DateTime? = nil,
        endDate: DateTime? = nil,
        place: Place? = nil,
        location: String? = nil,
        url: URL? = nil,
        organizer: Person? = nil,
        attendees: [Person]? = nil,
        status: String? = nil,
        plan: HolonRef? = nil,
        alarms: [Alarm]? = nil,
        handles: [Handle]? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.place = place
        self.location = location
        self.url = url
        self.organizer = organizer
        self.attendees = attendees
        self.status = status
        self.plan = plan
        self.alarms = alarms
        self.handles = handles
    }
}

extension Occurrence {
    /// Normalise a raw event-status string to Schema.org EventStatus vocabulary.
    public static func normalizedStatus(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        switch value.lowercased() {
        case "confirmed", "scheduled", "eventscheduled":  return "EventScheduled"
        case "cancelled", "canceled", "eventcancelled":   return "EventCancelled"
        case "postponed", "eventpostponed":               return "EventPostponed"
        case "rescheduled", "eventrescheduled":           return "EventRescheduled"
        case "movedonline", "eventmovedonline":           return "EventMovedOnline"
        default: return value
        }
    }
}

extension Occurrence: Codable {
    private enum CodingKeys: String, CodingKey {
        case meta
        case name, description, startDate, endDate
        case place, location, url, organizer, attendees = "attendee", status = "eventStatus", plan, alarms, handles
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        if encoder.codingPath.isEmpty {
            try container.encode(schema.org, forKey: .context)
        }
        try container.encode(String(describing: Self.self), forKey: .type)
        try container.encodeIfPresent(meta, forKey: .attribute(.meta))
        try container.encodeIfPresent(identifier, forKey: .id)
        try container.encodeIfPresent(name, forKey: .attribute(.name))
        try container.encodeIfPresent(description, forKey: .attribute(.description))
        try container.encodeIfPresent(startDate, forKey: .attribute(.startDate))
        try container.encodeIfPresent(endDate, forKey: .attribute(.endDate))
        try container.encodeIfPresent(place, forKey: .attribute(.place))
        try container.encodeIfPresent(location, forKey: .attribute(.location))
        try container.encodeIfPresent(url?.absoluteString, forKey: .attribute(.url))
        try container.encodeIfPresent(organizer, forKey: .attribute(.organizer))
        try container.encodeIfPresent(attendees, forKey: .attribute(.attendees))
        try container.encodeIfPresent(status, forKey: .attribute(.status))
        try container.encodeIfPresent(plan, forKey: .attribute(.plan))
        try container.encodeIfPresent(alarms, forKey: .attribute(.alarms))
        try container.encodeIfPresent(handles, forKey: .attribute(.handles))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        identifier = try container.decodeIfPresent(String.self, forKey: .id)
        meta = try container.decodeIfPresent(Meta.self, forKey: .attribute(.meta))
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        startDate = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.startDate))
        endDate = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.endDate))
        place = try container.decodeIfPresent(Place.self, forKey: .attribute(.place))
        location = try container.decodeIfPresent(String.self, forKey: .attribute(.location))
        if let urlString = try container.decodeIfPresent(String.self, forKey: .attribute(.url)) {
            url = URL(string: urlString)
        }
        organizer = try container.decodeIfPresent(Person.self, forKey: .attribute(.organizer))
        attendees = try container.decodeIfPresent([Person].self, forKey: .attribute(.attendees))
        status = try container.decodeIfPresent(String.self, forKey: .attribute(.status))
        plan = try container.decodeIfPresent(HolonRef.self, forKey: .attribute(.plan))
        alarms = try container.decodeIfPresent([Alarm].self, forKey: .attribute(.alarms))
        handles = try container.decodeIfPresent([Handle].self, forKey: .attribute(.handles))
    }
}
