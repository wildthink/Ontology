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
    /// Popup and email reminders for this event.
    public var reminders: Reminders?

    public struct EventDateTime: Codable, Sendable {
        public var dateTime: String?
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

    /// Google Calendar reminder override block.
    public struct Reminders: Codable, Sendable {
        public var useDefault: Bool?
        public var overrides: [Override]?

        public struct Override: Codable, Sendable {
            /// "popup" | "email"
            public var method: String?
            /// Minutes before the event start.
            public var minutes: Int?

            public init(method: String? = nil, minutes: Int? = nil) {
                self.method = method; self.minutes = minutes
            }
        }

        public init(useDefault: Bool? = nil, overrides: [Override]? = nil) {
            self.useDefault = useDefault; self.overrides = overrides
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
        recurringEventId: String? = nil,
        reminders: Reminders? = nil
    ) {
        self.id = id; self.summary = summary; self.description = description
        self.location = location; self.status = status; self.htmlLink = htmlLink
        self.start = start; self.end = end; self.organizer = organizer
        self.attendees = attendees; self.recurrence = recurrence
        self.recurringEventId = recurringEventId; self.reminders = reminders
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
        let calID = occurrence.handles?.value(for: Handle.Kind.googleCalendar) ?? occurrence.identifier
        self.init(
            id: calID,
            summary: occurrence.name,
            description: occurrence.description,
            location: occurrence.location ?? occurrence.place?.name,
            status: Self.denormalizedStatus(occurrence.status),
            htmlLink: occurrence.url?.absoluteString,
            start: occurrence.startDate.map { EventDateTime($0) },
            end: occurrence.endDate.map { EventDateTime($0) },
            organizer: occurrence.organizer.flatMap { Participant($0) },
            attendees: occurrence.attendees?.compactMap { Participant($0) },
            recurringEventId: planID,
            reminders: occurrence.alarms.map { Reminders(alarms: $0) }
        )
    }

    /// Create a GCalEvent body from a `Plan` (for insert / update of a recurring master).
    public init(_ plan: Plan) {
        // Google's `recurrence` is an array of RFC 5545 lines; RRULE and EXDATE
        // are separate entries, so a plan's cancelled instances ride alongside
        // the rule rather than inside it.
        var recurrence: [String] = []
        if let rrule = plan.rrule { recurrence.append("RRULE:\(rrule)") }
        if let exdate = RFC5545DateList.format(plan.exceptDates) {
            recurrence.append("EXDATE:\(exdate)")
        }
        let calID = plan.handles?.value(for: Handle.Kind.googleCalendar) ?? plan.identifier
        self.init(
            id: calID,
            summary: plan.name,
            description: plan.description,
            htmlLink: plan.url?.absoluteString,
            start: plan.startDate.map { EventDateTime($0) },
            end: plan.endDate.map { EventDateTime($0) },
            recurrence: recurrence.isEmpty ? nil : recurrence,
            reminders: plan.alarms.map { Reminders(alarms: $0) }
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
        let handles: [Handle]? = gcal.id.map { [Handle(kind: Handle.Kind.googleCalendar, value: $0)] }
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
            plan: planRef,
            alarms: gcal.reminders?.overrides?.map { Alarm(googleReminder: $0) },
            handles: handles
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
        let exceptDates = RFC5545DateList.parse(
            gcal.recurrence?.filter { $0.hasPrefix("EXDATE") } ?? []
        )
        let handles: [Handle]? = gcal.id.map { [Handle(kind: Handle.Kind.googleCalendar, value: $0)] }
        self.init(
            identifier: gcal.id,
            name: gcal.summary,
            description: gcal.description,
            startDate: gcal.start.flatMap { DateTime(googleDateTime: $0) },
            endDate: gcal.end.flatMap { DateTime(googleDateTime: $0) },
            url: gcal.htmlLink.flatMap { URL(string: $0) },
            rrule: rrule,
            exceptDates: exceptDates,
            alarms: gcal.reminders?.overrides?.map { Alarm(googleReminder: $0) },
            handles: handles
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

extension GCalEvent.Reminders {
    init(alarms: [Alarm]) {
        self.init(
            useDefault: false,
            overrides: alarms.map { GCalEvent.Reminders.Override($0) }
        )
    }
}

extension GCalEvent.Reminders.Override {
    public init(_ alarm: Alarm) {
        switch alarm.trigger {
        case .offsetMinutes(let n):
            let method = alarm.method == "email" ? "email" : "popup"
            self.init(method: method, minutes: abs(n))
        case .absoluteDate:
            // Google Calendar API does not support absolute-date reminders; fall back to 15 min.
            self.init(method: alarm.method == "email" ? "email" : "popup", minutes: 15)
        }
    }
}

extension Alarm {
    public init(googleReminder r: GCalEvent.Reminders.Override) {
        let method = r.method == "popup" ? "display" : (r.method ?? "display")
        self.init(trigger: .offsetMinutes(-(r.minutes ?? 15)), method: method)
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
