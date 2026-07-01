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
        case name, description, relatedTopics, tags
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        if encoder.codingPath.isEmpty {
            try container.encode(schema.org, forKey: .context)
        }
        try container.encode(String(describing: Self.self), forKey: .type)
        try container.encodeIfPresent(identifier, forKey: .id)
        try container.encodeIfPresent(name, forKey: .attribute(.name))
        try container.encodeIfPresent(description, forKey: .attribute(.description))
        try container.encodeIfPresent(relatedTopics, forKey: .attribute(.relatedTopics))
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
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        relatedTopics = try container.decodeIfPresent([HolonRef].self, forKey: .attribute(.relatedTopics))
        tags = try container.decodeIfPresent([String].self, forKey: .attribute(.tags))
    }
}
