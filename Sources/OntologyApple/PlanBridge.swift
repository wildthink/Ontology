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

    @discardableResult
    public func apply(to reminder: EKReminder) -> Bool {
        reminder.title = name ?? reminder.title
        reminder.notes = description
        reminder.url = url
        if let startDate {
            let tz = startDate.timeZone ?? .current
            reminder.dueDateComponents = Calendar.current.dateComponents(
                in: tz, from: startDate.value
            )
        }
        return true
    }

    public func makeEKReminder(
        in store: EKEventStore,
        list: EKCalendar? = nil
    ) -> EKReminder {
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list ?? store.defaultCalendarForNewReminders()
        apply(to: reminder)
        return reminder
    }
}
#endif
