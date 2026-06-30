import Foundation

/// A documented outcome: records what actually happened for a Plan or Occurrence.
public struct Record: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    /// The Plan or Occurrence this record documents.
    public var subject: HolonRef?
    /// Narrative of what actually happened.
    public var outcome: String?
    public var recordedAt: DateTime?

    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        subject: HolonRef? = nil,
        outcome: String? = nil,
        recordedAt: DateTime? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.subject = subject
        self.outcome = outcome
        self.recordedAt = recordedAt
    }
}

extension Record: SchemaEntityReference {
    public static var taxon: Taxon { .record }
}

extension Record: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, description, subject, outcome, recordedAt
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
        try container.encodeIfPresent(subject, forKey: .attribute(.subject))
        try container.encodeIfPresent(outcome, forKey: .attribute(.outcome))
        try container.encodeIfPresent(recordedAt, forKey: .attribute(.recordedAt))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        identifier = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        subject = try container.decodeIfPresent(HolonRef.self, forKey: .attribute(.subject))
        outcome = try container.decodeIfPresent(String.self, forKey: .attribute(.outcome))
        recordedAt = try container.decodeIfPresent(DateTime.self, forKey: .attribute(.recordedAt))
    }
}

extension Record: Entity {}
