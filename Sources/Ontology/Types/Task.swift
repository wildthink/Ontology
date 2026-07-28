import Foundation

/// An actionable unit of work inside a Plan.
public struct Task: Hashable, Sendable {
    public enum Status: String, Codable, Hashable, Sendable {
        case open
        case inProgress
        case done
        case cancelled
        case skipped
    }

    public enum SchedulingIntent: String, Codable, Hashable, Sendable {
        case asSoonAsPossible
        case soon
        case later
    }

    public var identifier: String?
    public var name: String?
    public var description: String?
    /// The Plan this task belongs to.
    public var plan: HolonRef?
    /// The person or org responsible for this task.
    public var assignee: HolonRef?
    public var dueDate: DateTime?
    /// Relative scheduling intent used when no exact due date is known.
    public var schedulingIntent: SchedulingIntent?
    public var status: Status
    public var statusChangedAt: DateTime?
    /// Lower number = higher priority.
    public var priority: Int?
    /// Alarms that prompt the assignee. These do not gate plan completion.
    public var alarms: [Alarm]?
    /// External and proxy identifiers for cross-system matching.
    public var handles: [Handle]?

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        plan: HolonRef? = nil,
        assignee: HolonRef? = nil,
        dueDate: DateTime? = nil,
        schedulingIntent: SchedulingIntent? = nil,
        status: Status = .open,
        statusChangedAt: DateTime? = nil,
        priority: Int? = nil,
        alarms: [Alarm]? = nil,
        handles: [Handle]? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.plan = plan
        self.assignee = assignee
        self.dueDate = dueDate
        self.schedulingIntent = schedulingIntent
        self.status = status
        self.statusChangedAt = statusChangedAt
        self.priority = priority
        self.alarms = alarms
        self.handles = handles
    }
}

extension Task: Codable {
    private enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case meta
        case name, description, plan, assignee, dueDate, schedulingIntent, status, statusChangedAt
        case priority, alarms, handles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.value(.identifier)
        meta = try container.value(.meta)
        name = try container.value(.name)
        description = try container.value(.description)
        plan = try container.value(.plan)
        assignee = try container.value(.assignee)
        dueDate = try container.value(.dueDate)
        let rawSchedulingIntent: String? = try container.value(.schedulingIntent)
        schedulingIntent = rawSchedulingIntent.flatMap(SchedulingIntent.init(rawValue:))
        let rawStatus: String? = try container.value(.status)
        status = rawStatus.flatMap(Status.init(rawValue:)) ?? .open
        statusChangedAt = try container.value(.statusChangedAt)
        priority = try container.value(.priority)
        alarms = try container.value(.alarms)
        handles = try container.value(.handles)
    }
}
