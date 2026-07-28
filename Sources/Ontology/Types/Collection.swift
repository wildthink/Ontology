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
        case identifier = "id"
        case meta
        case name, description, members
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(identifier, forKey: .identifier)
        try container.encodeIfPresent(meta, forKey: .meta)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        if !members.isEmpty {
            try container.encode(members, forKey: .members)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.value(.identifier)
        meta = try container.value(.meta)
        name = try container.value(.name)
        description = try container.value(.description)
        members = try container.value(.members, or: [])
    }
}

