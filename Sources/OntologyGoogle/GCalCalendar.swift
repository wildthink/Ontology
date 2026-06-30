import Foundation
import Ontology

// MARK: - Google Calendar API v3 — CalendarListEntry resource

/// https://developers.google.com/calendar/api/v3/reference/calendarList
public struct GCalCalendar: Decodable, Sendable {
    public let id: String?
    public let summary: String?
    public let description: String?
    public let timeZone: String?
    public let primary: Bool?
    public let accessRole: String?
}

/// Convenience wrapper for a Google CalendarList response.
public struct GCalCalendarList: Decodable, Sendable {
    public let items: [GCalCalendar]?
}

// MARK: - Collection bridge

extension Collection {
    public init(_ gcal: GCalCalendar) {
        self.init(
            identifier: gcal.id,
            name: gcal.summary,
            description: gcal.description
        )
    }
}
