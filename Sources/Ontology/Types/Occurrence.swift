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
        case identifier = "id"
        case meta
        case name, description, startDate, endDate
        case place, location, url, organizer, attendees = "attendee", status = "eventStatus", plan, alarms, handles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.value(.identifier)
        meta = try container.value(.meta)
        name = try container.value(.name)
        description = try container.value(.description)
        startDate = try container.value(.startDate)
        endDate = try container.value(.endDate)
        place = try container.value(.place)
        location = try container.value(.location)
        url = try container.lenientURL(.url)
        organizer = try container.value(.organizer)
        attendees = try container.value(.attendees)
        status = try container.value(.status)
        plan = try container.value(.plan)
        alarms = try container.value(.alarms)
        handles = try container.value(.handles)
    }
}
