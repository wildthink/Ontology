import Foundation

/// An organization following Schema.org ontology
public struct Organization: Hashable, Sendable {
    /// Unique identifier for the organization
    public var identifier: String?

    /// Name of the organization
    public var name: String?

    /// Physical addresses
    public var address: [PostalAddress]?

    /// Email addresses
    public var email: [String]?

    /// Telephone numbers
    public var telephone: [String]?

    /// URLs associated with the organization
    public var url: [String]?

    /// External and proxy identifiers for cross-system matching.
    public var handles: [Handle]?

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        address: [PostalAddress]? = nil,
        email: [String]? = nil,
        telephone: [String]? = nil,
        url: [String]? = nil,
        handles: [Handle]? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.address = address
        self.email = email
        self.telephone = telephone
        self.url = url
        self.handles = handles
    }

    /// Initialize an Organization with just a name
    public init(name: String) {
        self.identifier = nil
        self.name = name
        self.address = nil
        self.email = nil
        self.telephone = nil
        self.url = nil
        self.handles = nil
    }
}

extension Organization: Codable {
    private enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case meta
        case name, email, telephone, address, url, handles
    }
}
