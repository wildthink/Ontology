import Foundation

/// A generic subject or theme that other entities can reference — a tag with
/// its own identity and narrative, rather than a bare string.
///
/// ```markdown
/// ---
/// taxon: topic
/// id: topic.old-war
/// name: The Old War
/// ---
///
/// The war that ended the Third Age, referenced across many plans and records.
/// ```
public struct Topic: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    /// Other topics this one connects to (e.g. broader/narrower/related themes).
    public var relatedTopics: [HolonRef]?
    public var tags: [String]?

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        relatedTopics: [HolonRef]? = nil,
        tags: [String]? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.relatedTopics = relatedTopics
        self.tags = tags
    }
}

extension Topic: Codable {
    private enum CodingKeys: String, CodingKey {
        case meta
        case name, description, relatedTopics, tags
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        try container.encodeJSONLDHeader(Self.self, id: identifier, encoder: encoder)
        try container.encodeIfPresent(meta, forKey: .attribute(.meta))
        try container.encodeIfPresent(name, forKey: .attribute(.name))
        try container.encodeIfPresent(description, forKey: .attribute(.description))
        try container.encodeIfPresent(relatedTopics, forKey: .attribute(.relatedTopics))
        try container.encodeIfPresent(tags, forKey: .attribute(.tags))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        identifier = try container.decodeJSONLDHeader(Self.self)

        meta = try container.decodeIfPresent(Meta.self, forKey: .attribute(.meta))
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        relatedTopics = try container.decodeIfPresent([HolonRef].self, forKey: .attribute(.relatedTopics))
        tags = try container.decodeIfPresent([String].self, forKey: .attribute(.tags))
    }
}
