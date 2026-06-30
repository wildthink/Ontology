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
    /// The external system or proxy identifier type. Use `Handle.Kind` constants.
    public var kind: String
    /// The raw identifier value in that system.
    public var value: String
    /// Human-readable label, e.g. "Work", "Home", "Apple".
    public var label: String?

    public init(kind: String, value: String, label: String? = nil) {
        self.kind = kind
        self.value = value
        self.label = label
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
        public static let appleCalendarItemExt   = "apple.eventkit.external"

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
