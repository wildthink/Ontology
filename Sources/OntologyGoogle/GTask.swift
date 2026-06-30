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
    public init(_ plan: Plan) {
        self.init(
            id: plan.identifier,
            title: plan.name,
            notes: plan.description,
            due: plan.startDate.map { $0.googleDateTimeString },
            selfLink: plan.url?.absoluteString
        )
    }
}

// MARK: - GTask → Hub (read direction)

extension Plan {
    public init(_ g: GTask) {
        self.init(
            identifier: g.id,
            name: g.title,
            description: g.notes,
            startDate: g.due.flatMap { DateTime.parseISO8601($0) }.map { DateTime($0) },
            url: g.selfLink.flatMap { URL(string: $0) }
        )
    }
}
