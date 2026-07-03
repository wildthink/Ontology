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
        case meta
        case name, from, to, kind, reciprocal, note
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
        try container.encode(from, forKey: .attribute(.from))
        try container.encode(to, forKey: .attribute(.to))
        try container.encode(kind, forKey: .attribute(.kind))
        try container.encodeIfPresent(reciprocal, forKey: .attribute(.reciprocal))
        try container.encodeIfPresent(note, forKey: .attribute(.note))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        let describedType = String(describing: Self.self)
        if let decodedType = try container.decodeIfPresent(String.self, forKey: .type),
           decodedType != describedType {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected type to be '\(describedType)', but found \(decodedType)"
            )
        }

        identifier = try container.decodeIfPresent(String.self, forKey: .id)

        meta = try container.decodeIfPresent(Meta.self, forKey: .attribute(.meta))
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        from = try container.decode(HolonRef.self, forKey: .attribute(.from))
        to = try container.decode(HolonRef.self, forKey: .attribute(.to))
        kind = try container.decode(String.self, forKey: .attribute(.kind))
        reciprocal = try container.decodeIfPresent(Bool.self, forKey: .attribute(.reciprocal))
        note = try container.decodeIfPresent(String.self, forKey: .attribute(.note))
    }
}
