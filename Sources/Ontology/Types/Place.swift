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

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


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
        case identifier = "id"
        case meta
        case name, description, address, geo, telephone, url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.value(.identifier)
        meta = try container.value(.meta)
        name = try container.value(.name)
        description = try container.value(.description)
        address = try container.value(.address)
        geo = try container.value(.geo)
        telephone = try container.value(.telephone)
        url = try container.lenientURL(.url)
    }
}
