/// A contact point following Schema.org ontology
public struct ContactPoint: Hashable, Sendable {
    public var contactType: String
    public var identifier: String

    public init(contactType: String, identifier: String) {
        self.contactType = contactType
        self.identifier = identifier
    }
}

extension ContactPoint: Codable {
    private enum CodingKeys: String, CodingKey {
        case contactType, identifier
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        try container.encodeJSONLDHeader(Self.self, encoder: encoder)

        // Encode properties
        try container.encode(contactType, forKey: .attribute(.contactType))
        try container.encode(identifier, forKey: .attribute(.identifier))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        _ = try container.decodeJSONLDHeader(Self.self)

        // Decode properties
        contactType = try container.decode(String.self, forKey: .attribute(.contactType))
        identifier = try container.decode(String.self, forKey: .attribute(.identifier))
    }
}
