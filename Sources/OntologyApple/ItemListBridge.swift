#if canImport(EventKit)
import EventKit
import Ontology

extension ItemList {
    public init(_ calendar: EKCalendar) {
        self.init(name: calendar.title)
        self.identifier = calendar.calendarIdentifier
    }
}
#endif
