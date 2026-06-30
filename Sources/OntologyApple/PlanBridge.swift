#if canImport(EventKit)
import EventKit
import Ontology

extension Plan {
    /// Create a Plan from an EKReminder.
    ///
    /// Mapping: title → name, notes → description, dueDateComponents → startDate, url → url.
    /// Completion state and priority have no Plan equivalent; use a `Record` to document outcomes.
    public init(_ reminder: EKReminder) {
        let dueDate = reminder.dueDateComponents
            .flatMap { Calendar.current.date(from: $0) }
            .map { DateTime($0) }
        self.init(
            identifier: reminder.calendarItemIdentifier,
            name: reminder.title,
            description: reminder.notes,
            startDate: dueDate,
            url: reminder.url
        )
    }
}
#endif
