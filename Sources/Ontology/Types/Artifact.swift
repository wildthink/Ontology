import Foundation

/// An in-fiction object with its own identity — a prop, weapon, document, or
/// other possession. Distinct from `Media`: an `Artifact` is the thing itself
/// (narrative, ownership, location); `Media` is a picture/recording of it.
///
/// ```markdown
/// ---
/// taxon: artifact
/// id: artifact.evermore-blade
/// name: The Evermore Blade
/// owner: "[[person.3f8a91b2]]"
/// media: "[[media.evermore-blade-photo]]"
/// tags: [weapon, magic]
/// ---
///
/// Forged in the Old War, said to sing when drawn near danger.
/// ```
public struct Artifact: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    /// Who currently possesses this artifact, if anyone.
    public var owner: HolonRef?
    /// Where the artifact currently is, if not with an owner (e.g. a `Place`).
    public var location: HolonRef?
    /// An illustration or photo of this artifact, if any.
    public var media: HolonRef?
    public var tags: [String]?

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        owner: HolonRef? = nil,
        location: HolonRef? = nil,
        media: HolonRef? = nil,
        tags: [String]? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.owner = owner
        self.location = location
        self.media = media
        self.tags = tags
    }
}

extension Artifact: Codable {
    private enum CodingKeys: String, CodingKey {
        case meta
        case name, description, owner, location, media, tags
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
        try container.encodeIfPresent(owner, forKey: .attribute(.owner))
        try container.encodeIfPresent(location, forKey: .attribute(.location))
        try container.encodeIfPresent(media, forKey: .attribute(.media))
        try container.encodeIfPresent(tags, forKey: .attribute(.tags))
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
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        owner = try container.decodeIfPresent(HolonRef.self, forKey: .attribute(.owner))
        location = try container.decodeIfPresent(HolonRef.self, forKey: .attribute(.location))
        media = try container.decodeIfPresent(HolonRef.self, forKey: .attribute(.media))
        tags = try container.decodeIfPresent([String].self, forKey: .attribute(.tags))
    }
}
