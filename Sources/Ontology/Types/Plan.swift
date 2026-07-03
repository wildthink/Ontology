import Foundation

/// An intent, goal, or coordination object.
/// The primary user-facing entity in the planning workflow.
///
/// Lifecycle (via `status`): "opportunity" → "planning" → "active" → "completed" | "cancelled"
///
/// An Opportunity is a Plan with `status: Plan.Status.opportunity` and a `subject` pointing to
/// the seed `Occurrence`. A ScheduleItem is an `Occurrence` whose `plan` back-references here.
/// Associated Reminders and calendar events serve the plan but don't gate completion.
public struct Plan: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    /// Lifecycle state — see `Plan.Status` for vocabulary.
    public var status: String?
    public var startDate: DateTime?
    public var endDate: DateTime?
    /// Target completion date. Distinct from `endDate` (when a scheduled block ends).
    public var dueDate: DateTime?
    public var location: Place?
    public var url: URL?
    /// RFC 5545 RRULE string, e.g. "FREQ=WEEKLY;BYDAY=FR"
    public var rrule: String?
    public var tags: [String]?
    /// Who owns this plan.
    public var owner: HolonRef?
    /// People and orgs involved.
    public var participants: [HolonRef]?
    /// The seed opportunity or external event that originated this plan.
    public var subject: HolonRef?
    /// Estimated work (e.g. 4 hours, 3 story points).
    public var effort: QuantitativeValue?
    /// Alarms attached to this plan. These prompt the owner but do not gate plan completion.
    public var alarms: [Alarm]?
    /// External and proxy identifiers for cross-system matching.
    public var handles: [Handle]?

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        status: String? = nil,
        startDate: DateTime? = nil,
        endDate: DateTime? = nil,
        dueDate: DateTime? = nil,
        location: Place? = nil,
        url: URL? = nil,
        rrule: String? = nil,
        tags: [String]? = nil,
        owner: HolonRef? = nil,
        participants: [HolonRef]? = nil,
        subject: HolonRef? = nil,
        effort: QuantitativeValue? = nil,
        alarms: [Alarm]? = nil,
        handles: [Handle]? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.dueDate = dueDate
        self.location = location
        self.url = url
        self.rrule = rrule
        self.tags = tags
        self.owner = owner
        self.participants = participants
        self.subject = subject
        self.effort = effort
        self.alarms = alarms
        self.handles = handles
    }
}

// MARK: - Codable

extension Plan: Codable {
    private enum CodingKeys: String, CodingKey {
        case meta
        case name, description, status, startDate, endDate, dueDate
        case location, url, rrule, tags, owner, participants, subject, effort, alarms, handles
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        if encoder.codingPath.isEmpty { try c.encode(schema.org, forKey: .context) }
        try c.encode(String(describing: Self.self), forKey: .type)
        try c.encodeIfPresent(identifier, forKey: .id)
        try c.encodeIfPresent(name, forKey: .attribute(.name))
        try c.encodeIfPresent(description, forKey: .attribute(.description))
        try c.encodeIfPresent(status, forKey: .attribute(.status))
        try c.encodeIfPresent(startDate, forKey: .attribute(.startDate))
        try c.encodeIfPresent(endDate, forKey: .attribute(.endDate))
        try c.encodeIfPresent(dueDate, forKey: .attribute(.dueDate))
        try c.encodeIfPresent(location, forKey: .attribute(.location))
        try c.encodeIfPresent(url?.absoluteString, forKey: .attribute(.url))
        try c.encodeIfPresent(rrule, forKey: .attribute(.rrule))
        try c.encodeIfPresent(tags, forKey: .attribute(.tags))
        try c.encodeIfPresent(owner, forKey: .attribute(.owner))
        try c.encodeIfPresent(participants, forKey: .attribute(.participants))
        try c.encodeIfPresent(subject, forKey: .attribute(.subject))
        try c.encodeIfPresent(effort, forKey: .attribute(.effort))
        try c.encodeIfPresent(alarms, forKey: .attribute(.alarms))
        try c.encodeIfPresent(handles, forKey: .attribute(.handles))
        try c.encodeIfPresent(meta, forKey: .attribute(.meta))
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        identifier = try c.decodeIfPresent(String.self, forKey: .id)
        meta = try c.decodeIfPresent(Meta.self, forKey: .attribute(.meta))
        name = try c.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try c.decodeIfPresent(String.self, forKey: .attribute(.description))
        status = try c.decodeIfPresent(String.self, forKey: .attribute(.status))
        startDate = try c.decodeIfPresent(DateTime.self, forKey: .attribute(.startDate))
        endDate = try c.decodeIfPresent(DateTime.self, forKey: .attribute(.endDate))
        dueDate = try c.decodeIfPresent(DateTime.self, forKey: .attribute(.dueDate))
        location = try c.decodeIfPresent(Place.self, forKey: .attribute(.location))
        if let s = try c.decodeIfPresent(String.self, forKey: .attribute(.url)) { url = URL(string: s) }
        rrule = try c.decodeIfPresent(String.self, forKey: .attribute(.rrule))
        tags = try c.decodeIfPresent([String].self, forKey: .attribute(.tags))
        owner = try c.decodeIfPresent(HolonRef.self, forKey: .attribute(.owner))
        participants = try c.decodeIfPresent([HolonRef].self, forKey: .attribute(.participants))
        subject = try c.decodeIfPresent(HolonRef.self, forKey: .attribute(.subject))
        effort = try c.decodeIfPresent(QuantitativeValue.self, forKey: .attribute(.effort))
        alarms = try c.decodeIfPresent([Alarm].self, forKey: .attribute(.alarms))
        handles = try c.decodeIfPresent([Handle].self, forKey: .attribute(.handles))
    }
}

// MARK: - Status vocabulary

extension Plan {
    /// String constants for `Plan.status`.
    public enum Status {
        /// A discovered possibility not yet committed to.
        public static let opportunity = "opportunity"
        /// Being shaped: tasks defined, participants identified.
        public static let planning    = "planning"
        /// Work underway.
        public static let active      = "active"
        /// Successfully finished.
        public static let completed   = "completed"
        /// Abandoned without completion.
        public static let cancelled   = "cancelled"
        /// Paused; intent to resume.
        public static let onHold      = "on-hold"
    }
}

// MARK: - Grouping convenience

extension Plan {
    /// Create a `Collection` that groups the given member refs under this plan's identity.
    /// Useful for gathering all child Task and Commitment refs into a queryable collection.
    public func collection(members: [HolonRef]) -> Collection {
        Collection(
            identifier: identifier.map { "collection.\($0)" },
            name: name,
            description: description,
            members: members
        )
    }
}
