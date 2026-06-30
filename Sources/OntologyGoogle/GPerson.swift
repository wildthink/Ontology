import Foundation
import Ontology

// MARK: - Google People API v1 — Person resource

/// https://developers.google.com/people/api/rest/v1/people
public struct GPerson: Codable, Sendable {
    /// e.g. "people/c1234567890"
    public var resourceName: String?
    public var names: [NameEntry]?
    public var emailAddresses: [ValueEntry]?
    public var phoneNumbers: [ValueEntry]?
    public var organizations: [OrgEntry]?
    public var addresses: [AddressEntry]?
    public var urls: [ValueEntry]?
    public var birthdays: [BirthdayEntry]?

    public struct NameEntry: Codable, Sendable {
        public var givenName: String?
        public var familyName: String?
        public var displayName: String?

        public init(givenName: String? = nil, familyName: String? = nil, displayName: String? = nil) {
            self.givenName = givenName; self.familyName = familyName; self.displayName = displayName
        }
    }

    public struct ValueEntry: Codable, Sendable {
        public var value: String?
        public var type: String?

        public init(value: String? = nil, type: String? = nil) {
            self.value = value; self.type = type
        }
    }

    public struct OrgEntry: Codable, Sendable {
        public var name: String?
        public var title: String?

        public init(name: String? = nil, title: String? = nil) {
            self.name = name; self.title = title
        }
    }

    public struct AddressEntry: Codable, Sendable {
        public var streetAddress: String?
        public var city: String?
        public var region: String?
        public var postalCode: String?
        public var country: String?
        public var type: String?

        public init(
            streetAddress: String? = nil, city: String? = nil, region: String? = nil,
            postalCode: String? = nil, country: String? = nil, type: String? = nil
        ) {
            self.streetAddress = streetAddress; self.city = city; self.region = region
            self.postalCode = postalCode; self.country = country; self.type = type
        }
    }

    public struct BirthdayEntry: Codable, Sendable {
        public var date: BirthdayDate?

        public struct BirthdayDate: Codable, Sendable {
            public var year: Int?
            public var month: Int?
            public var day: Int?
        }
    }

    public init(
        resourceName: String? = nil,
        names: [NameEntry]? = nil,
        emailAddresses: [ValueEntry]? = nil,
        phoneNumbers: [ValueEntry]? = nil,
        organizations: [OrgEntry]? = nil,
        addresses: [AddressEntry]? = nil,
        urls: [ValueEntry]? = nil,
        birthdays: [BirthdayEntry]? = nil
    ) {
        self.resourceName = resourceName; self.names = names
        self.emailAddresses = emailAddresses; self.phoneNumbers = phoneNumbers
        self.organizations = organizations; self.addresses = addresses
        self.urls = urls; self.birthdays = birthdays
    }
}

/// Convenience wrapper for a People `connections.list` response.
public struct GPersonList: Codable, Sendable {
    public var connections: [GPerson]?
}

// MARK: - Hub → GPerson (write direction)

extension GPerson {
    public init(_ person: Person) {
        let nameEntry: NameEntry? = (person.givenName != nil || person.familyName != nil)
            ? NameEntry(
                givenName: person.givenName,
                familyName: person.familyName,
                displayName: [person.givenName, person.familyName]
                    .compactMap { $0 }.joined(separator: " ")
              )
            : nil
        let orgEntry: OrgEntry? = (person.worksFor?.name != nil || person.jobTitle != nil)
            ? OrgEntry(name: person.worksFor?.name, title: person.jobTitle)
            : nil
        self.init(
            resourceName: person.identifier,
            names: nameEntry.map { [$0] },
            emailAddresses: person.email?.map { ValueEntry(value: $0) },
            phoneNumbers: person.telephone?.map { ValueEntry(value: $0) },
            organizations: orgEntry.map { [$0] },
            urls: person.url?.map { ValueEntry(value: $0) }
        )
    }
}

// MARK: - GPerson → Hub (read direction)

extension Person {
    public init(_ g: GPerson) {
        let primary = g.names?.first
        self.init(
            givenName: primary?.givenName,
            familyName: primary?.familyName
        )
        identifier = g.resourceName
        email = g.emailAddresses?.compactMap(\.value)
        telephone = g.phoneNumbers?.compactMap(\.value)
        jobTitle = g.organizations?.first?.title
        worksFor = g.organizations?.first?.name.map { Organization(name: $0) }
        url = g.urls?.compactMap(\.value)
    }
}

extension Organization {
    init(name: String) {
        self.init()
        self.name = name
    }
}
