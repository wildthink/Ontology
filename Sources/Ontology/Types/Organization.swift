import Foundation

/// An organization following Schema.org ontology
public struct Organization: Hashable, Sendable {
    /// Unique identifier for the organization
    public var identifier: String?

    /// Name of the organization
    public var name: String?

    /// Physical addresses associated with the person
    public var address: [PostalAddress]?

    /// Email addresses associated with the person
    public var email: [String]?

    /// Telephone numbers associated with the person
    public var telephone: [String]?

    /// URLs associated with the organization
    public var url: [String]?

    /// Non-schema extension point for provider-specific fields.
    public var metadata: [String: String]

    public init(
        identifier: String? = nil,
        name: String? = nil,
        address: [PostalAddress]? = nil,
        email: [String]? = nil,
        telephone: [String]? = nil,
        url: [String]? = nil,
        metadata: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.name = name
        self.address = address
        self.email = email
        self.telephone = telephone
        self.url = url
        self.metadata = metadata
    }

    /// Initialize an Organization with just a name
    public init(name: String) {
        self.identifier = nil
        self.name = name
        self.address = nil
        self.email = nil
        self.telephone = nil
        self.url = nil
        self.metadata = [:]
    }
}

extension Organization: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, email, telephone, address, url, metadata
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        // Encode @context if we're at the root level (empty coding path)
        if encoder.codingPath.isEmpty {
            try container.encode(schema.org, forKey: .context)
        }

        // Encode @type
        try container.encode(String(describing: Self.self), forKey: .type)

        // Encode @id
        try container.encodeIfPresent(identifier, forKey: .id)

        // Encode properties
        try container.encodeIfPresent(name, forKey: .attribute(.name))
        try container.encodeIfPresent(email, forKey: .attribute(.email))
        try container.encodeIfPresent(telephone, forKey: .attribute(.telephone))
        try container.encodeIfPresent(address, forKey: .attribute(.address))
        try container.encodeIfPresent(url, forKey: .attribute(.url))
        try container.encode(metadata, forKey: .attribute(.metadata))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        // Decode properties
        identifier = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        email = try container.decodeIfPresent([String].self, forKey: .attribute(.email))
        telephone = try container.decodeIfPresent([String].self, forKey: .attribute(.telephone))
        address = try container.decodeIfPresent([PostalAddress].self, forKey: .attribute(.address))
        url = try container.decodeIfPresent([String].self, forKey: .attribute(.url))
        metadata = try container.decodeIfPresent([String: String].self, forKey: .attribute(.metadata)) ?? [:]
    }
}
