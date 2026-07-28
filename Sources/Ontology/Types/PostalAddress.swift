/// A postal address following Schema.org ontology
public struct PostalAddress: Hashable, Sendable {
    /// The street address
    public var streetAddress: String?

    /// The locality
    public var addressLocality: String?

    /// The region
    public var addressRegion: String?

    /// The postal code
    public var postalCode: String?

    /// The country
    public var addressCountry: String?

    public init(
        streetAddress: String? = nil,
        addressLocality: String? = nil,
        addressRegion: String? = nil,
        postalCode: String? = nil,
        addressCountry: String? = nil
    ) {
        self.streetAddress = streetAddress
        self.addressLocality = addressLocality
        self.addressRegion = addressRegion
        self.postalCode = postalCode
        self.addressCountry = addressCountry
    }
}

extension PostalAddress: Codable {
    private enum CodingKeys: String, CodingKey {
        case streetAddress, addressLocality, addressRegion, postalCode, addressCountry
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        try container.encodeJSONLDHeader(Self.self, encoder: encoder)

        // Encode properties
        try container.encodeIfPresent(streetAddress, forKey: .attribute(.streetAddress))
        try container.encodeIfPresent(addressLocality, forKey: .attribute(.addressLocality))
        try container.encodeIfPresent(addressRegion, forKey: .attribute(.addressRegion))
        try container.encodeIfPresent(postalCode, forKey: .attribute(.postalCode))
        try container.encodeIfPresent(addressCountry, forKey: .attribute(.addressCountry))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        _ = try container.decodeJSONLDHeader(Self.self)

        // Decode properties
        streetAddress = try container.decodeIfPresent(
            String.self, forKey: .attribute(.streetAddress))
        addressLocality = try container.decodeIfPresent(
            String.self, forKey: .attribute(.addressLocality))
        addressRegion = try container.decodeIfPresent(
            String.self, forKey: .attribute(.addressRegion))
        // Postal codes are schema.org Text, but an unquoted numeric code (e.g. `94016`)
        // parses out of YAML/JSON as a number — decode leniently so it still lands as a String.
        postalCode = try container.decodeStringLeniently(forKey: .attribute(.postalCode))
        addressCountry = try container.decodeIfPresent(
            String.self, forKey: .attribute(.addressCountry))
    }
}
