import Foundation

/// A relational promise or obligation between actors within a Plan.
///
/// Models: self-commitment, invitation, acceptance, delegation, and completion acknowledgement.
public struct Commitment: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    /// The Plan this commitment belongs to.
    public var plan: HolonRef?
    /// Who made the commitment.
    public var actor: HolonRef?
    /// To whom the commitment is made (nil = self-commitment).
    public var recipient: HolonRef?
    /// Semantic role: "invitation" | "acceptance" | "delegation" | "acknowledgement" | "self"
    public var role: String?
    /// "pending" | "accepted" | "declined" | "completed" | "cancelled"
    public var status: String?
    public var dueDate: DateTime?
    public var note: String?

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        plan: HolonRef? = nil,
        actor: HolonRef? = nil,
        recipient: HolonRef? = nil,
        role: String? = nil,
        status: String? = nil,
        dueDate: DateTime? = nil,
        note: String? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.plan = plan
        self.actor = actor
        self.recipient = recipient
        self.role = role
        self.status = status
        self.dueDate = dueDate
        self.note = note
    }
}

extension Commitment: Codable {
    private enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case meta
        case name, plan, actor, recipient, role, status, dueDate, note
    }
}

// MARK: - Status vocabulary

extension Commitment {
    /// String constants for `Commitment.status`.
    public enum Status {
        public static let pending       = "pending"
        public static let accepted      = "accepted"
        public static let declined      = "declined"
        public static let completed     = "completed"
        public static let cancelled     = "cancelled"
    }

    /// String constants for `Commitment.role`.
    public enum Role {
        public static let invitation     = "invitation"
        public static let acceptance     = "acceptance"
        public static let delegation     = "delegation"
        public static let acknowledgement = "acknowledgement"
        public static let selfCommitment  = "self"
    }
}
