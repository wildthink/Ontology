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
    /// Link to the artifact (document, recording, etc.) this record refers to.
    public var url: URL?

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        subject: HolonRef? = nil,
        outcome: String? = nil,
        recordedAt: DateTime? = nil,
        url: URL? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.subject = subject
        self.outcome = outcome
        self.recordedAt = recordedAt
        self.url = url
    }
}

extension Record: Codable {
    private enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case meta
        case name, description, subject, outcome, recordedAt, url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.value(.identifier)
        meta = try container.value(.meta)
        name = try container.value(.name)
        description = try container.value(.description)
        subject = try container.value(.subject)
        outcome = try container.value(.outcome)
        recordedAt = try container.value(.recordedAt)
        url = try container.lenientURL(.url)
    }
}

