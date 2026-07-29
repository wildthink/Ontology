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
    /// Dates removed from the `rrule` recurrence — RFC 5545 `EXDATE`, which lives
    /// on its own line rather than inside the RRULE. A cancelled instance of a
    /// recurring plan lands here.
    public var exceptDates: [DateTime]?
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
        exceptDates: [DateTime]? = nil,
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
        self.exceptDates = exceptDates
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
        case identifier = "id"
        case meta
        case name, description, status, startDate, endDate, dueDate
        case location, url, rrule, exceptDates, tags
        case owner, participants, subject
        case effort, alarms, handles
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(identifier, forKey: .identifier)
        try c.encodeIfPresent(meta, forKey: .meta)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(startDate, forKey: .startDate)
        try c.encodeIfPresent(endDate, forKey: .endDate)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encodeIfPresent(location, forKey: .location)
        try c.encodeIfPresent(url?.absoluteString, forKey: .url)
        try c.encodeIfPresent(rrule, forKey: .rrule)
        try c.encodeIfPresent(exceptDates, forKey: .exceptDates)
        try c.encodeIfPresent(tags, forKey: .tags)
        try c.encodeIfPresent(owner, forKey: .owner)
        try c.encodeIfPresent(participants, forKey: .participants)
        try c.encodeIfPresent(subject, forKey: .subject)
        try c.encodeIfPresent(effort, forKey: .effort)
        try c.encodeIfPresent(alarms, forKey: .alarms)
        try c.encodeIfPresent(handles, forKey: .handles)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try c.value(.identifier)
        meta = try c.value(.meta)
        name = try c.value(.name)
        description = try c.value(.description)
        status = try c.value(.status)
        startDate = try c.value(.startDate)
        endDate = try c.value(.endDate)
        dueDate = try c.value(.dueDate)
        location = try c.value(.location)
        url = try c.lenientURL(.url)
        rrule = try c.value(.rrule)
        exceptDates = try c.value(.exceptDates)
        tags = try c.value(.tags)
        owner = try c.value(.owner)
        participants = try c.value(.participants)
        subject = try c.value(.subject)
        effort = try c.value(.effort)
        alarms = try c.value(.alarms)
        handles = try c.value(.handles)
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

// MARK: - Completion

extension Plan {
    /// Whether this plan may be marked `completed`, given its action items.
    ///
    /// A plan is completable when no action item is still `open` or `inProgress` —
    /// clear stragglers by marking them done, skipped, or cancelled. A plan with no
    /// action items is completable.
    ///
    /// Deliberately ignores `Task.progress` and `alarms`. Progress is an advisory
    /// note of what's up and alarms are informational; neither gates completion.
    /// Do not "fix" this by requiring every countable item to have reached its goal —
    /// "I did it" is the check-off, not the count.
    ///
    /// `Plan` does not store its tasks — they back-reference it via `Task.plan` — so
    /// the caller supplies them.
    public func isCompletable(given tasks: [Task]) -> Bool {
        !tasks.contains { $0.status == .open || $0.status == .inProgress }
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
