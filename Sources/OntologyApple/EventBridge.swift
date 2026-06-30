#if canImport(EventKit)
import EventKit
import Ontology

extension Event {
    public init(_ ekEvent: EKEvent) {
        self.init(
            identifier: ekEvent.calendarItemIdentifier,
            name: ekEvent.title,
            description: ekEvent.notes,
            calendar: ekEvent.calendar.map {
                Calendar(identifier: $0.calendarIdentifier, title: $0.title)
            },
            startDate: DateTime(ekEvent.startDate, timeZone: ekEvent.timeZone),
            endDate: DateTime(ekEvent.endDate, timeZone: ekEvent.timeZone),
            location: ekEvent.location ?? ekEvent.structuredLocation?.title,
            url: ekEvent.url,
            organizer: ekEvent.organizer.flatMap(Person.init),
            attendee: ekEvent.attendees?.compactMap(Person.init),
            eventStatus: Self.normalizedEventStatus(Self.eventKitStatus(from: ekEvent.status)),
            metadata: Self.eventKitMetadata(from: ekEvent)
        )
    }

    @discardableResult
    public func apply(to event: EKEvent, defaultDuration: TimeInterval = 3600) -> Bool {
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
        case .confirmed: return "confirmed"
        case .tentative: return "tentative"
        case .canceled:  return "cancelled"
        case .none:      return nil
        @unknown default: return nil
        }
    }

    private static func eventKitMetadata(from event: EKEvent) -> [String: String] {
        var metadata: [String: String] = ["isAllDay": String(event.isAllDay)]
        if let id = event.eventIdentifier { metadata["eventIdentifier"] = id }
        metadata["calendarItemIdentifier"] = event.calendarItemIdentifier
        metadata["calendarItemExternalIdentifier"] = event.calendarItemExternalIdentifier
        if let tz = event.timeZone?.identifier { metadata["timeZone"] = tz }
        return metadata
    }
}

extension Person {
    fileprivate init?(_ participant: EKParticipant) {
        let candidateName = (participant.name?.isEmpty == false)
            ? participant.name! : participant.url.absoluteString
        guard !candidateName.isEmpty else { return nil }
        self.init(name: candidateName)
        self.identifier = participant.url.absoluteString
        let url = participant.url
        if url.scheme?.lowercased() == "mailto" {
            let address = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            if !address.isEmpty { self.email = [address] }
        }
    }
}
#endif
