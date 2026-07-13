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
        case meta
        case name, description, plan, assignee, dueDate, schedulingIntent, status, statusChangedAt
        case priority, alarms, handles
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        if encoder.codingPath.isEmpty {
            try container.encode(schema.org, forKey: .context)
        }
        try container.encode(String(describing: Self.self), forKey: .type)
        try container.encodeIfPresent(meta, forKey: .attribute(.meta))
        try container.encodeIfPresent(identifier, forKey: .id)
        try container.encodeIfPresent(name, forKey: .attribute(.name))
        try container.encodeIfPresent(description, forKey: .attribute(.description))
        try container.encodeIfPresent(plan, forKey: .attribute(.plan))
        try container.encodeIfPresent(assignee, forKey: .attribute(.assignee))
        try container.encodeIfPresent(dueDate, forKey: .attribute(.dueDate))
        try container.encodeIfPresent(schedulingIntent?.rawValue, forKey: .attribute(.schedulingIntent))
        try container.encode(status.rawValue, forKey: .attribute(.status))
        try container.encodeIfPresent(statusChangedAt, forKey: .attribute(.statusChangedAt))
        try container.encodeIfPresent(priority, forKey: .attribute(.priority))
        try container.encodeIfPresent(alarms, forKey: .attribute(.alarms))
        try container.encodeIfPresent(handles, forKey: .attribute(.handles))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        identifier = try container.decodeIfPresent(String.self, forKey: .id)
        meta = try container.decodeIfPresent(Meta.self, forKey: .attribute(.meta))
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        plan = try container.decodeIfPresent(HolonRef.self, forKey: .attribute(.plan))
        assignee = try container.decodeIfPresent(HolonRef.self, forKey: .attribute(.assignee))
        dueDate = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.dueDate))
        let rawSchedulingIntent = try container.decodeIfPresent(String.self, forKey: .attribute(.schedulingIntent))
        schedulingIntent = rawSchedulingIntent.flatMap(SchedulingIntent.init(rawValue:))
        let rawStatus = try container.decodeIfPresent(String.self, forKey: .attribute(.status))
        status = rawStatus.flatMap(Status.init(rawValue:)) ?? .open
        statusChangedAt = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.statusChangedAt))
        priority = try container.decodeIfPresent(Int.self, forKey: .attribute(.priority))
        alarms = try container.decodeIfPresent([Alarm].self, forKey: .attribute(.alarms))
        handles = try container.decodeIfPresent([Handle].self, forKey: .attribute(.handles))
    }
}
