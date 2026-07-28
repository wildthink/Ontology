import Foundation

/// A Person model following Schema.org ontology (https://schema.org/Person)
public struct Person: Hashable, Sendable {
    /// Unique identifier for the person
    public var identifier: String?

    /// Full display name (https://schema.org/name). Bridges and providers
    /// populate this with the formatted full name; `givenName`/`familyName`
    /// remain the structured components.
    public var name: String?

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

    /// External and proxy identifiers for cross-system matching.
    public var handles: [Handle]?

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

    /// Open, schema-free metadata (see `Meta`).
    public var meta: Meta?

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
        handles: [Handle]? = nil,
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
        self.handles = handles
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
        #if os(Linux)
        let parts = name.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if parts.count >= 2 {
            self.init(givenName: parts.first, familyName: parts.dropFirst().joined(separator: " "))
        } else {
            self.init(givenName: parts.first ?? name)
        }
        #else
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
        #endif
        self.name = name
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
        case meta
        case name
        case givenName, familyName, email, telephone, address
        case jobTitle, worksFor, url, birthDate, sameAs, handles
        case contactPoint, knowsLanguage, preferences
        case spouse, children, siblings, parents, relatedTo
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        
        try container.encodeJSONLDHeader(Self.self, id: identifier, encoder: encoder)
        try container.encodeIfPresent(meta, forKey: .attribute(.meta))

        // Encode properties
        try container.encodeIfPresent(name, forKey: .attribute(.name))
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
        try container.encodeIfPresent(handles, forKey: .attribute(.handles))
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
        
        identifier = try container.decodeJSONLDHeader(Self.self)

        meta = try container.decodeIfPresent(Meta.self, forKey: .attribute(.meta))
        
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        givenName = try container.decodeIfPresent(String.self, forKey: .attribute(.givenName))
        familyName = try container.decodeIfPresent(String.self, forKey: .attribute(.familyName))
        email = container.decodeFlexibleStringList(forKey: .attribute(.email))
        telephone = container.decodeFlexibleStringList(forKey: .attribute(.telephone))
        address = try container.decodeIfPresent([PostalAddress].self, forKey: .attribute(.address))
        jobTitle = try container.decodeIfPresent(String.self, forKey: .attribute(.jobTitle))
        worksFor = try container.decodeIfPresent(Organization.self, forKey: .attribute(.worksFor))
        url = container.decodeFlexibleStringList(forKey: .attribute(.url))
        birthDate = try container.decodeIfPresent(String.self, forKey: .attribute(.birthDate))
        sameAs = container.decodeFlexibleStringList(forKey: .attribute(.sameAs))
        handles = try container.decodeIfPresent([Handle].self, forKey: .attribute(.handles))
        contactPoint = try container.decodeIfPresent(
            [ContactPoint].self, forKey: .attribute(.contactPoint))
        knowsLanguage = container.decodeFlexibleStringList(forKey: .attribute(.knowsLanguage))
        spouse = try container.decodeIfPresent([Person].self, forKey: .attribute(.spouse))
        children = try container.decodeIfPresent([Person].self, forKey: .attribute(.children))
        siblings = try container.decodeIfPresent([Person].self, forKey: .attribute(.siblings))
        parents = try container.decodeIfPresent([Person].self, forKey: .attribute(.parents))
        relatedTo = try container.decodeIfPresent([Person].self, forKey: .attribute(.relatedTo))
    }
}
