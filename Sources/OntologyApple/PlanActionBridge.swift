#if canImport(EventKit)
import EventKit
import Ontology

extension PlanAction {
    public init(_ reminder: EKReminder) {
        self.init(
            name: reminder.title ?? "",
            dueDate: reminder.dueDateComponents?.date,
            description: reminder.notes,
            completed: reminder.isCompleted
        )
        self.priority = reminder.priority > 0 ? reminder.priority : nil
        self.url = reminder.url
        if let calendar = reminder.calendar {
            self.object = ItemList(calendar)
        }
    }
}
#endif
