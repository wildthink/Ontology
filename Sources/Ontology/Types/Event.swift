import Foundation

/// An Event model following Schema.org ontology (https://schema.org/Event),
/// with a few pragmatic extensions for app-specific interoperability.
public struct Event: Hashable, Sendable {
    /// Unique identifier for the event
    public var identifier: String?

    /// The name/title of the event
    public var name: String?

    /// A description of the event
    public var description: String?

    /// The calendar this event belongs to
    public var calendar: String?

    /// Start date and time of the event in ISO 8601 format
    public var startDate: DateTime?

    /// End date and time of the event in ISO 8601 format
    public var endDate: DateTime?

    /// Location where the event takes place
    public var location: String?

    /// URLs associated with the event
    public var url: URL?

    /// Organizer of the event
    public var organizer: Person?

    /// Attendees of the event
    public var attendee: [Person]?

    /// Event status aligned with Schema.org `eventStatus` when possible.
    public var eventStatus: String?

    /// Non-schema extension point for provider-specific fields.
    public var metadata: [String: String]

    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        calendar: String? = nil,
        startDate: DateTime? = nil,
        endDate: DateTime? = nil,
        location: String? = nil,
        url: URL? = nil,
        organizer: Person? = nil,
        attendee: [Person]? = nil,
        eventStatus: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.calendar = calendar
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.url = url
        self.organizer = organizer
        self.attendee = attendee
        self.eventStatus = eventStatus
        self.metadata = metadata
    }

    public init(
        name: String,
        dates: Range<Date>
    ) {
        self.init(
            name: name,
            startDate: DateTime(dates.lowerBound),
            endDate: DateTime(dates.upperBound)
        )
    }

    public init(
        name: String,
        dates: ClosedRange<Date>
    ) {
        self.init(
            name: name,
            startDate: DateTime(dates.lowerBound),
            endDate: DateTime(dates.upperBound)
        )
    }
}

public extension Event {
    var isAllDay: Bool {
        metadata["isAllDay"]?.lowercased() == "true"
    }

    static func normalizedEventStatus(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }

        switch value.lowercased() {
        case "confirmed", "scheduled", "eventscheduled":
            return "EventScheduled"
        case "cancelled", "canceled", "eventcancelled":
            return "EventCancelled"
        case "postponed", "eventpostponed":
            return "EventPostponed"
        case "rescheduled", "eventrescheduled":
            return "EventRescheduled"
        case "movedonline", "eventmovedonline":
            return "EventMovedOnline"
        default:
            return value
        }
    }
}

#if canImport(EventKit)
    import EventKit

    extension Event {
        /// Initialize an Event with an EventKit event
        public init(_ event: EKEvent) {
            self.identifier = event.calendarItemIdentifier
            self.name = event.title
            self.description = event.notes
            self.calendar = event.calendar.title
            self.startDate = DateTime(event.startDate, timeZone: event.timeZone)
            self.endDate = DateTime(event.endDate, timeZone: event.timeZone)
            self.location = event.location ?? event.structuredLocation?.title
            self.url = event.url
            self.organizer = event.organizer.flatMap(Person.init)
            self.attendee = event.attendees?.compactMap(Person.init)
            self.eventStatus = Self.normalizedEventStatus(Self.eventKitStatus(from: event.status))
            self.metadata = Self.eventKitMetadata(from: event)
        }

        @discardableResult
        public func apply(
            to event: EKEvent,
            defaultDuration: TimeInterval = 3600
        ) -> Bool {
            guard let start = startDate?.value else { return false }

            event.title = name ?? event.title
            event.notes = description
            event.startDate = start
            event.endDate = endDate?.value ?? start.addingTimeInterval(defaultDuration)
            event.isAllDay = isAllDay
            event.location = location
            event.url = url
            event.timeZone = startDate?.timeZone ?? endDate?.timeZone
            return true
        }

        public func makeEKEvent(
            in store: EKEventStore,
            calendar: EKCalendar? = nil,
            defaultDuration: TimeInterval = 3600
        ) -> EKEvent? {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar ?? store.defaultCalendarForNewEvents
            return apply(to: event, defaultDuration: defaultDuration) ? event : nil
        }

        private static func eventKitStatus(from status: EKEventStatus) -> String? {
            switch status {
            case .confirmed:
                return "confirmed"
            case .tentative:
                return "tentative"
            case .canceled:
                return "cancelled"
            case .none:
                return nil
            @unknown default:
                return nil
            }
        }

        private static func eventKitMetadata(from event: EKEvent) -> [String: String] {
            var metadata: [String: String] = [
                "isAllDay": String(event.isAllDay)
            ]

            if let eventIdentifier = event.eventIdentifier {
                metadata["eventIdentifier"] = eventIdentifier
            }
            metadata["calendarItemIdentifier"] = event.calendarItemIdentifier
            metadata["calendarItemExternalIdentifier"] = event.calendarItemExternalIdentifier
            if let timeZoneIdentifier = event.timeZone?.identifier {
                metadata["timeZone"] = timeZoneIdentifier
            }
            return metadata
        }
    }

    extension Person {
        fileprivate init?(_ participant: EKParticipant) {
            let candidateName = (participant.name?.isEmpty == false)
                ? participant.name!
                : participant.url.absoluteString
            guard !candidateName.isEmpty else { return nil }

            self.init(name: candidateName)
            self.identifier = participant.url.absoluteString

            let url = participant.url
            if url.scheme?.lowercased() == "mailto" {
                let address = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                if !address.isEmpty {
                    self.email = [address]
                }
            }
        }
    }
#endif

extension Event: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, description, startDate, endDate, location, url, calendar
        case organizer, attendee, eventStatus, metadata
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
        try container.encodeIfPresent(calendar, forKey: .attribute(.calendar))
        try container.encodeIfPresent(startDate, forKey: .attribute(.startDate))
        try container.encodeIfPresent(endDate, forKey: .attribute(.endDate))
        try container.encodeIfPresent(location, forKey: .attribute(.location))
        try container.encodeIfPresent(url, forKey: .attribute(.url))
        try container.encodeIfPresent(organizer, forKey: .attribute(.organizer))
        try container.encodeIfPresent(attendee, forKey: .attribute(.attendee))
        try container.encodeIfPresent(eventStatus, forKey: .attribute(.eventStatus))
        try container.encode(metadata, forKey: .attribute(.metadata))
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
        calendar = try container.decodeIfPresent(String.self, forKey: .attribute(.calendar))
        startDate = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.startDate))
        endDate = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.endDate))
        location = try container.decodeIfPresent(String.self, forKey: .attribute(.location))
        url = try container.decodeIfPresent(URL.self, forKey: .attribute(.url))
        organizer = try container.decodeIfPresent(Person.self, forKey: .attribute(.organizer))
        attendee = try container.decodeIfPresent([Person].self, forKey: .attribute(.attendee))
        eventStatus = try container.decodeIfPresent(String.self, forKey: .attribute(.eventStatus))
        metadata = try container.decodeIfPresent([String: String].self, forKey: .attribute(.metadata)) ?? [:]
    }
}
