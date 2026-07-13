import Foundation
import Ontology

// MARK: - Google Tasks API v1 — Task resource

/// https://developers.google.com/tasks/reference/rest/v1/tasks
public struct GTask: Codable, Sendable {
    public var id: String?
    public var title: String?
    public var notes: String?
    /// "needsAction" | "completed"
    public var status: String?
    /// UTC midnight of the due date: "2024-01-15T00:00:00.000Z"
    public var due: String?
    public var selfLink: String?
    public var updated: String?

    public init(
        id: String? = nil,
        title: String? = nil,
        notes: String? = nil,
        status: String? = nil,
        due: String? = nil,
        selfLink: String? = nil,
        updated: String? = nil
    ) {
        self.id = id; self.title = title; self.notes = notes; self.status = status
        self.due = due; self.selfLink = selfLink; self.updated = updated
    }
}

/// Convenience wrapper for a Google Tasks `tasks.list` response.
public struct GTaskList: Codable, Sendable {
    public var items: [GTask]?
}

// MARK: - Hub → GTask (write direction)

extension GTask {
    /// Create a GTask body from a `Task` (for insert / update via the API).
    public init(_ task: Task) {
        self.init(
            id: task.handles?.value(for: Handle.Kind.googleTasks) ?? task.identifier,
            title: task.name,
            notes: task.description,
            status: Self.googleStatus(task.status),
            due: task.dueDate.map { $0.googleDateTimeString }
        )
    }

    /// Create a GTask body from a `Plan` (for insert / update via the API).
    public init(_ plan: Plan) {
        self.init(
            id: plan.identifier,
            title: plan.name,
            notes: plan.description,
            due: (plan.dueDate ?? plan.startDate).map { $0.googleDateTimeString },
            selfLink: plan.url?.absoluteString
        )
    }

    static func googleStatus(_ s: Task.Status) -> String {
        switch s {
        case .done:                    return "completed"
        case .open, .inProgress, .cancelled, .skipped: return "needsAction"
        }
    }
}

// MARK: - GTask → Hub (read direction)

extension Task {
    /// Create a `Task` from a Google Task resource.
    /// The `plan` back-reference is not set here — wire it at call site if known.
    public init(_ g: GTask) {
        self.init(
            identifier: g.id,
            name: g.title,
            description: g.notes,
            dueDate: g.due.flatMap { DateTime.parseISO8601($0) }.map { DateTime($0) },
            status: g.status == "completed" ? .done : .open,
            handles: g.id.map { [Handle(kind: Handle.Kind.googleTasks, value: $0)] }
        )
    }
}

extension Plan {
    /// Create a `Plan` from a Google Task resource.
    public init(_ g: GTask) {
        self.init(
            identifier: g.id,
            name: g.title,
            description: g.notes,
            startDate: g.due.flatMap { DateTime.parseISO8601($0) }.map { DateTime($0) },
            url: g.selfLink.flatMap { URL(string: $0) },
            handles: g.id.map { [Handle(kind: Handle.Kind.googleTasks, value: $0)] }
        )
    }
}
