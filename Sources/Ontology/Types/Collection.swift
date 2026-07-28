import Foundation

/// A logical grouping of Holons, independent of directory layout.
///
/// Persisted as `_index.md` files. The `members` list declares logical
/// membership via `HolonRef` values — a `Person` in `people/jane.md` can
/// belong to a campaign arc's collection without moving the file.
///
/// ```markdown
/// ---
/// taxon: collection
/// id: collection.arc1
/// name: The Dragon Arc
/// ---
///
/// First arc of the Evermore campaign.
/// ```
public struct Collection: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    /// The holons that belong to this collection.
    public var members: [HolonRef]

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        members: [HolonRef] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.members = members
    }
}

extension Collection: Codable {
    private enum CodingKeys: String, CodingKey {
        case meta
        case name, description, members
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        try container.encodeJSONLDHeader(Self.self, id: identifier, encoder: encoder)
        try container.encodeIfPresent(meta, forKey: .attribute(.meta))
        try container.encodeIfPresent(name, forKey: .attribute(.name))
        try container.encodeIfPresent(description, forKey: .attribute(.description))
        if !members.isEmpty {
            try container.encode(members, forKey: .attribute(.members))
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        identifier = try container.decodeJSONLDHeader(Self.self)
        meta = try container.decodeIfPresent(Meta.self, forKey: .attribute(.meta))
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        members = try container.decodeIfPresent([HolonRef].self, forKey: .attribute(.members)) ?? []
    }
}

