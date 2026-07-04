#if canImport(EventKit)
import EventKit
import Ontology

// MARK: - Task ↔ EKReminder

extension Task {
    /// Create a Task from an EKReminder.
    ///
    /// Mapping: title → name, notes → description, dueDateComponents → dueDate,
    /// isCompleted → .done | .open, alarms → alarms.
    /// The `plan` back-reference is not set here — wire it at call site if known.
    public init(_ reminder: EKReminder) {
        let due = reminder.dueDateComponents
            .flatMap { Calendar.current.date(from: $0) }
            .map { DateTime($0) }
        self.init(
            identifier: reminder.calendarItemIdentifier,
            name: reminder.title,
            description: reminder.notes,
            dueDate: due,
            status: reminder.isCompleted ? .done : .open,
            priority: reminder.priority == 0 ? nil : reminder.priority,
            alarms: reminder.alarms?.map(Alarm.init(_:)),
            handles: [Handle(kind: Handle.Kind.appleCalendarItem, value: reminder.calendarItemIdentifier)]
        )
    }

    /// Write task fields onto an existing EKReminder.
    @discardableResult
    public func apply(to reminder: EKReminder) -> Bool {
        reminder.title = name ?? reminder.title
        reminder.notes = description
        reminder.isCompleted = status == .done
        if let dueDate {
            let tz = dueDate.timeZone ?? .current
            reminder.dueDateComponents = Calendar.current.dateComponents(in: tz, from: dueDate.value)
        }
        reminder.alarms = alarms?.map { $0.ekAlarm() }
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
