import Foundation

/// A Person model following Schema.org ontology (https://schema.org/Person)
public struct Person: Hashable, Sendable {
    /// Unique identifier for the person
    public var identifier: String?
    
    /// Given name (first name) of the person
    public var givenName: String?
    
    /// Family name (last name) of the person
    public var familyName: String?
    
    /// Email addresses associated with the person
    public var email: [String]?
    
    /// Telephone numbers associated with the person
    public var telephone: [String]?
    
    /// Physical addresses associated with the person
    public var address: [PostalAddress]?
    
    /// Job title of the person
    public var jobTitle: String?
    
    /// Organization the person works for
    public var worksFor: Organization?
    
    /// URLs associated with the person (e.g. websites, profiles)
    public var url: [String]?
    
    /// Date of birth in ISO 8601 format (YYYY-MM-DD)
    public var birthDate: String?
    
    /// Social profile URLs for the person
    public var sameAs: [String]?
    
    /// Contact points (e.g. instant messaging)
    public var contactPoint: [ContactPoint]?
    
    /// Languages known by the person (ISO language codes)
    public var knowsLanguage: [String]?
    
    /// Family relationships
    public var spouse: [Person]?
    public var children: [Person]?
    public var siblings: [Person]?
    public var parents: [Person]?
    public var relatedTo: [Person]?

    public init(
        identifier: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        email: [String]? = nil,
        telephone: [String]? = nil,
        address: [PostalAddress]? = nil,
        jobTitle: String? = nil,
        worksFor: Organization? = nil,
        url: [String]? = nil,
        birthDate: String? = nil,
        sameAs: [String]? = nil,
        contactPoint: [ContactPoint]? = nil,
        knowsLanguage: [String]? = nil,
        spouse: [Person]? = nil,
        children: [Person]? = nil,
        siblings: [Person]? = nil,
        parents: [Person]? = nil,
        relatedTo: [Person]? = nil
    ) {
        self.identifier = identifier
        self.givenName = givenName
        self.familyName = familyName
        self.email = email
        self.telephone = telephone
        self.address = address
        self.jobTitle = jobTitle
        self.worksFor = worksFor
        self.url = url
        self.birthDate = birthDate
        self.sameAs = sameAs
        self.contactPoint = contactPoint
        self.knowsLanguage = knowsLanguage
        self.spouse = spouse
        self.children = children
        self.siblings = siblings
        self.parents = parents
        self.relatedTo = relatedTo
    }
}

public extension Person {
    /// Initialize a Person by parsing a full name string.
    init(name: String) {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: name) {
            self.init(givenName: components.givenName, familyName: components.familyName)
        } else {
            let parts = name.components(separatedBy: " ")
            if parts.count >= 2 {
                self.init(givenName: parts[0], familyName: parts.last)
            } else {
                self.init(givenName: parts[0])
            }
        }
    }
}

public extension Person {
    var personName: PersonNameComponents {
        PersonNameComponents(
            givenName: self.givenName,
            familyName: self.familyName
        )
    }
}

extension Person: Codable {
    private enum CodingKeys: String, CodingKey {
        case givenName, familyName, email, telephone, address
        case jobTitle, worksFor, url, birthDate, sameAs
        case contactPoint, knowsLanguage, preferences
        case spouse, children, siblings, parents, relatedTo
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
        try container.encodeIfPresent(givenName, forKey: .attribute(.givenName))
        try container.encodeIfPresent(familyName, forKey: .attribute(.familyName))
        try container.encodeIfPresent(email, forKey: .attribute(.email))
        try container.encodeIfPresent(telephone, forKey: .attribute(.telephone))
        try container.encodeIfPresent(address, forKey: .attribute(.address))
        try container.encodeIfPresent(jobTitle, forKey: .attribute(.jobTitle))
        try container.encodeIfPresent(worksFor, forKey: .attribute(.worksFor))
        try container.encodeIfPresent(url, forKey: .attribute(.url))
        try container.encodeIfPresent(birthDate, forKey: .attribute(.birthDate))
        try container.encodeIfPresent(sameAs, forKey: .attribute(.sameAs))
        try container.encodeIfPresent(contactPoint, forKey: .attribute(.contactPoint))
        try container.encodeIfPresent(knowsLanguage, forKey: .attribute(.knowsLanguage))
        try container.encodeIfPresent(spouse, forKey: .attribute(.spouse))
        try container.encodeIfPresent(children, forKey: .attribute(.children))
        try container.encodeIfPresent(siblings, forKey: .attribute(.siblings))
        try container.encodeIfPresent(parents, forKey: .attribute(.parents))
        try container.encodeIfPresent(relatedTo, forKey: .attribute(.relatedTo))
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        
        // Verify type is correct
        let describedType = String(describing: Self.self)
        let decodedType = try container.decode(String.self, forKey: .type)
        guard decodedType == describedType else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected type to be '\(describedType)', but found \(decodedType)"
            )
        }
        
        // Decode @id
        identifier = try container.decodeIfPresent(String.self, forKey: .id)
        
        givenName = try container.decodeIfPresent(String.self, forKey: .attribute(.givenName))
        familyName = try container.decodeIfPresent(String.self, forKey: .attribute(.familyName))
        email = try container.decodeIfPresent([String].self, forKey: .attribute(.email))
        telephone = try container.decodeIfPresent([String].self, forKey: .attribute(.telephone))
        address = try container.decodeIfPresent([PostalAddress].self, forKey: .attribute(.address))
        jobTitle = try container.decodeIfPresent(String.self, forKey: .attribute(.jobTitle))
        worksFor = try container.decodeIfPresent(Organization.self, forKey: .attribute(.worksFor))
        url = try container.decodeIfPresent([String].self, forKey: .attribute(.url))
        birthDate = try container.decodeIfPresent(String.self, forKey: .attribute(.birthDate))
        sameAs = try container.decodeIfPresent([String].self, forKey: .attribute(.sameAs))
        contactPoint = try container.decodeIfPresent(
            [ContactPoint].self, forKey: .attribute(.contactPoint))
        knowsLanguage = try container.decodeIfPresent(
            [String].self, forKey: .attribute(.knowsLanguage))
        spouse = try container.decodeIfPresent([Person].self, forKey: .attribute(.spouse))
        children = try container.decodeIfPresent([Person].self, forKey: .attribute(.children))
        siblings = try container.decodeIfPresent([Person].self, forKey: .attribute(.siblings))
        parents = try container.decodeIfPresent([Person].self, forKey: .attribute(.parents))
        relatedTo = try container.decodeIfPresent([Person].self, forKey: .attribute(.relatedTo))
    }
}
