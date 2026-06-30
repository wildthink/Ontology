import Foundation
import Ontology

// MARK: - Google Calendar API v3 — Event resource

/// https://developers.google.com/calendar/api/v3/reference/events
public struct GCalEvent: Codable, Sendable {
    public var id: String?
    public var summary: String?
    public var description: String?
    public var location: String?
    /// "confirmed" | "tentative" | "cancelled"
    public var status: String?
    public var htmlLink: String?
    public var start: EventDateTime?
    public var end: EventDateTime?
    public var organizer: Participant?
    public var attendees: [Participant]?
    /// RFC 5545 lines, e.g. ["RRULE:FREQ=WEEKLY;BYDAY=FR", "EXDATE;..."]
    public var recurrence: [String]?
    /// Set on instances of a recurring series; points to the master event id.
    public var recurringEventId: String?

    public struct EventDateTime: Codable, Sendable {
        /// ISO 8601 date-time (timed events).
        public var dateTime: String?
        /// ISO 8601 date only, YYYY-MM-DD (all-day events).
        public var date: String?
        public var timeZone: String?

        public init(dateTime: String? = nil, date: String? = nil, timeZone: String? = nil) {
            self.dateTime = dateTime; self.date = date; self.timeZone = timeZone
        }
    }

    public struct Participant: Codable, Sendable {
        public var email: String?
        public var displayName: String?
        public var responseStatus: String?

        public init(email: String? = nil, displayName: String? = nil, responseStatus: String? = nil) {
            self.email = email; self.displayName = displayName; self.responseStatus = responseStatus
        }
    }

    public init(
        id: String? = nil,
        summary: String? = nil,
        description: String? = nil,
        location: String? = nil,
        status: String? = nil,
        htmlLink: String? = nil,
        start: EventDateTime? = nil,
        end: EventDateTime? = nil,
        organizer: Participant? = nil,
        attendees: [Participant]? = nil,
        recurrence: [String]? = nil,
        recurringEventId: String? = nil
    ) {
        self.id = id; self.summary = summary; self.description = description
        self.location = location; self.status = status; self.htmlLink = htmlLink
        self.start = start; self.end = end; self.organizer = organizer
        self.attendees = attendees; self.recurrence = recurrence
        self.recurringEventId = recurringEventId
    }
}

/// Convenience wrapper for a Google Calendar Events list response.
public struct GCalEventList: Codable, Sendable {
    public var items: [GCalEvent]?
}

// MARK: - Hub → GCalEvent (write direction)

extension GCalEvent {
    /// Create a GCalEvent body from an `Occurrence` (for insert / update via the API).
    public init(_ occurrence: Occurrence) {
        let planID: String? = occurrence.plan.flatMap {
            if case .entity(_, let id) = $0 { return id }
            return nil
        }
        self.init(
            id: occurrence.identifier,
            summary: occurrence.name,
            description: occurrence.description,
            location: occurrence.location ?? occurrence.place?.name,
            status: Self.denormalizedStatus(occurrence.status),
            htmlLink: occurrence.url?.absoluteString,
            start: occurrence.startDate.map { EventDateTime($0) },
            end: occurrence.endDate.map { EventDateTime($0) },
            organizer: occurrence.organizer.flatMap { Participant($0) },
            attendees: occurrence.attendees?.compactMap { Participant($0) },
            recurringEventId: planID
        )
    }

    /// Create a GCalEvent body from a `Plan` (for insert / update of a recurring master).
    public init(_ plan: Plan) {
        let rrule = plan.rrule.map { "RRULE:\($0)" }
        self.init(
            id: plan.identifier,
            summary: plan.name,
            description: plan.description,
            htmlLink: plan.url?.absoluteString,
            start: plan.startDate.map { EventDateTime($0) },
            end: plan.endDate.map { EventDateTime($0) },
            recurrence: rrule.map { [$0] }
        )
    }

    /// Convert Schema.org EventStatus back to Google Calendar status vocabulary.
    static func denormalizedStatus(_ s: String?) -> String? {
        guard let s else { return nil }
        switch s {
        case "EventScheduled":                     return "confirmed"
        case "EventCancelled":                     return "cancelled"
        case "EventPostponed", "EventRescheduled": return "tentative"
        default:                                   return s.lowercased()
        }
    }
}

// MARK: - GCalEvent → Hub (read direction)

extension Occurrence {
    public init(_ gcal: GCalEvent) {
        let planRef: HolonRef? = gcal.recurringEventId.map { .entity(.plan, $0) }
        self.init(
            identifier: gcal.id,
            name: gcal.summary,
            description: gcal.description,
            startDate: gcal.start.flatMap { DateTime(googleDateTime: $0) },
            endDate: gcal.end.flatMap { DateTime(googleDateTime: $0) },
            location: gcal.location,
            url: gcal.htmlLink.flatMap { URL(string: $0) },
            organizer: gcal.organizer.flatMap { Person(googleParticipant: $0) },
            attendees: gcal.attendees?.compactMap { Person(googleParticipant: $0) },
            status: Occurrence.normalizedStatus(gcal.status),
            plan: planRef
        )
    }
}

extension Plan {
    /// Create a `Plan` from a Google Calendar recurring event master.
    /// Use on events that carry a `recurrence` array.
    public init(_ gcal: GCalEvent) {
        let rrule = gcal.recurrence?
            .first(where: { $0.hasPrefix("RRULE:") })
            .map { String($0.dropFirst(6)) }
        self.init(
            identifier: gcal.id,
            name: gcal.summary,
            description: gcal.description,
            startDate: gcal.start.flatMap { DateTime(googleDateTime: $0) },
            endDate: gcal.end.flatMap { DateTime(googleDateTime: $0) },
            url: gcal.htmlLink.flatMap { URL(string: $0) },
            rrule: rrule
        )
    }
}

// MARK: - Internal helpers

extension GCalEvent.EventDateTime {
    init(_ dt: DateTime) {
        self.init(dateTime: dt.googleDateTimeString, timeZone: dt.timeZone?.identifier)
    }
}

extension GCalEvent.Participant {
    init?(_ person: Person) {
        guard let email = person.email?.first else { return nil }
        let name = [person.givenName, person.familyName].compactMap { $0 }.joined(separator: " ")
        self.init(email: email, displayName: name.isEmpty ? nil : name)
    }
}

extension DateTime {
    var googleDateTimeString: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = timeZone ?? .gmt
        return f.string(from: value)
    }

    init?(googleDateTime dt: GCalEvent.EventDateTime) {
        if let str = dt.dateTime {
            guard let date = DateTime.parseISO8601(str) else { return nil }
            let tz = dt.timeZone.flatMap { TimeZone(identifier: $0) }
            self.init(date, timeZone: tz)
        } else if let str = dt.date {
            let tz = dt.timeZone.flatMap { TimeZone(identifier: $0) } ?? .gmt
            let parts = str.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            let comps = DateComponents(year: parts[0], month: parts[1], day: parts[2])
            guard let date = cal.date(from: comps) else { return nil }
            self.init(date, timeZone: tz)
        } else {
            return nil
        }
    }

    static func parseISO8601(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string)
    }
}

extension Person {
    init?(googleParticipant p: GCalEvent.Participant) {
        guard let email = p.email, !email.isEmpty else { return nil }
        self.init(name: p.displayName ?? email)
        self.email = [email]
    }
}
