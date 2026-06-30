import Foundation

/// A geographical location, such as a specific address or point of interest.
public struct Place: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    public var address: PostalAddress?
    public var geo: GeoCoordinates?
    public var telephone: String?
    public var url: URL?

    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        address: PostalAddress? = nil,
        geo: GeoCoordinates? = nil,
        telephone: String? = nil,
        url: URL? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.address = address
        self.geo = geo
        self.telephone = telephone
        self.url = url
    }
}

extension Place: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, description, address, geo, telephone, url
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
        try container.encodeIfPresent(address, forKey: .attribute(.address))
        try container.encodeIfPresent(geo, forKey: .attribute(.geo))
        try container.encodeIfPresent(telephone, forKey: .attribute(.telephone))
        try container.encodeIfPresent(url?.absoluteString, forKey: .attribute(.url))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        identifier = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        address = try container.decodeIfPresent(PostalAddress.self, forKey: .attribute(.address))
        geo = try container.decodeIfPresent(GeoCoordinates.self, forKey: .attribute(.geo))
        telephone = try container.decodeIfPresent(String.self, forKey: .attribute(.telephone))
        let urlString = try container.decodeIfPresent(String.self, forKey: .attribute(.url))
        url = urlString.flatMap { URL(string: $0) }
    }
}
