import Foundation

/// A typed identifier for an entity in an external system, or a proxy identifier
/// (such as an email address) that can be used for cross-system entity matching.
///
/// Inspired by `INPersonHandle`. Unlike a single `identifier` field, an entity
/// can carry multiple handles — one per external system — enabling deduplication
/// when the same real-world object is imported from more than one source.
///
/// `kind` is an open string so new systems can be added without changing this type.
/// Use the `Handle.Kind` constants for known systems.
public struct Handle: Hashable, Codable, Sendable {
    public enum Role: String, Codable, Hashable, Sendable {
        case canonical
        case alias
        case externalReference
    }
    /// The external system or proxy identifier type. Use `Handle.Kind` constants.
    public var kind: String
    /// The raw identifier value in that system.
    public var value: String
    /// Human-readable label, e.g. "Work", "Home", "Apple".
    public var label: String?
    public var role: Role
    /// Groups canonical and alternate handles for one external record.
    public var group: String?

    public init(
        kind: String,
        value: String,
        label: String? = nil,
        role: Role = .canonical,
        group: String? = nil
    ) {
        self.kind = kind
        self.value = value
        self.label = label
        self.role = role
        self.group = group
    }

    private enum CodingKeys: String, CodingKey {
        case kind, value, label, role, group
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(String.self, forKey: .kind)
        value = try container.decode(String.self, forKey: .value)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        role = try container.decodeIfPresent(Role.self, forKey: .role) ?? .canonical
        group = try container.decodeIfPresent(String.self, forKey: .group)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(group, forKey: .group)
    }
}

// MARK: - Kind vocabulary

extension Handle {
    /// String constants for well-known `Handle.kind` values.
    public enum Kind {
        // Proxy identifiers — values the entity already carries, used as lookup keys
        public static let email  = "email"
        public static let phone  = "phone"
        public static let url    = "url"

        // Apple system identifiers
        public static let appleContacts          = "apple.contacts"
        public static let appleCalendarItem      = "apple.eventkit.item"
        public static let appleCalendarEvent     = "apple.eventkit.event"
        public static let appleReminder          = "apple.eventkit.reminder"
        public static let appleCalendarItemExt   = "apple.eventkit.external"
        public static let appleSpotlight         = "apple.spotlight"

        // Web provenance — the page a record was extracted from
        public static let webPage                = "web.page"

        // Google system identifiers
        public static let googlePeople   = "google.people"
        public static let googleCalendar = "google.calendar"
        public static let googleTasks    = "google.tasks"
    }
}

// MARK: - Collection helpers

extension Array where Element == Handle {
    /// Returns the first handle value matching `kind`, or nil.
    public func value(for kind: String) -> String? {
        first { $0.kind == kind }?.value
    }

    /// Returns all handles matching `kind`.
    public func all(for kind: String) -> [Handle] {
        filter { $0.kind == kind }
    }

    /// Returns true if any handle matches `kind` and `value`.
    public func contains(kind: String, value: String) -> Bool {
        contains { $0.kind == kind && $0.value == value }
    }
}
