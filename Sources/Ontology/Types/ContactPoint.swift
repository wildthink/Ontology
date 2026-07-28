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
}
