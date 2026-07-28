import Foundation

/// A reified, typed connection between two actors (`Person`/`Organization`),
/// independent of any single `Plan`.
///
/// Where `Commitment` models an obligation within a Plan, `Relationship`
/// models standing social structure — rivalries, mentorships, family ties,
/// faction membership — that exists whether or not a Plan ever references it.
///
/// ```markdown
/// ---
/// taxon: relationship
/// id: relationship.mentor01
/// from: "[[person.3f8a91b2]]"
/// to: "[[person.player01]]"
/// kind: mentor
/// reciprocal: false
/// ---
///
/// Jane has trained Sam since the campaign's second arc.
/// ```
public struct Relationship: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    /// The actor the relationship is described from.
    public var from: HolonRef
    /// The actor on the other end of the relationship.
    public var to: HolonRef
    /// Semantic label, e.g. "mentor", "rival", "sibling", "member-of".
    public var kind: String
    /// Whether `kind` reads identically in both directions (e.g. "sibling")
    /// vs. is directional (e.g. "mentor" implies `to` is the one being mentored).
    public var reciprocal: Bool?
    public var note: String?

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        from: HolonRef,
        to: HolonRef,
        kind: String,
        reciprocal: Bool? = nil,
        note: String? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.from = from
        self.to = to
        self.kind = kind
        self.reciprocal = reciprocal
        self.note = note
    }
}

extension Relationship: Codable {
    private enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case meta
        case name, from, to, kind, reciprocal, note
    }
}
