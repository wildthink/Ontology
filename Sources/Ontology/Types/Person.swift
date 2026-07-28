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
        case identifier = "id"
        case meta
        case name
        case givenName, familyName, email, telephone, address
        case jobTitle, worksFor, url, birthDate, sameAs, handles
        case contactPoint, knowsLanguage
        case spouse, children, siblings, parents, relatedTo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        identifier = try container.value(.identifier)

        meta = try container.value(.meta)
        
        name = try container.value(.name)
        givenName = try container.value(.givenName)
        familyName = try container.value(.familyName)
        email = container.decodeFlexibleStringList(forKey: .email)
        telephone = container.decodeFlexibleStringList(forKey: .telephone)
        address = try container.value(.address)
        jobTitle = try container.value(.jobTitle)
        worksFor = try container.value(.worksFor)
        url = container.decodeFlexibleStringList(forKey: .url)
        birthDate = try container.value(.birthDate)
        sameAs = container.decodeFlexibleStringList(forKey: .sameAs)
        handles = try container.value(.handles)
        contactPoint = try container.value(.contactPoint)
        knowsLanguage = container.decodeFlexibleStringList(forKey: .knowsLanguage)
        spouse = try container.value(.spouse)
        children = try container.value(.children)
        siblings = try container.value(.siblings)
        parents = try container.value(.parents)
        relatedTo = try container.value(.relatedTo)
    }
}
