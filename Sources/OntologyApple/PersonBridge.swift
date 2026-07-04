#if canImport(Contacts)
import Contacts
import Foundation
import Ontology

extension Person {
    public init?(_ contact: CNContact) {
        guard contact.contactType == .person else { return nil }

        let address: [PostalAddress]? = contact.postalAddresses.isEmpty
            ? nil : contact.postalAddresses.map { PostalAddress($0.value) }

        var birthDate: String?
        if let birthday = contact.birthday {
            var dc = DateComponents()
            dc.year = birthday.year; dc.month = birthday.month; dc.day = birthday.day
            if let date = Calendar.current.date(from: dc) {
                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                birthDate = fmt.string(from: date)
            }
        }

        let contactPoint: [ContactPoint]? = contact.instantMessageAddresses.isEmpty
            ? nil : contact.instantMessageAddresses.map { ContactPoint($0.value) }

        self.init(
            identifier: contact.identifier,
            givenName: contact.givenName.isEmpty ? nil : contact.givenName,
            familyName: contact.familyName.isEmpty ? nil : contact.familyName,
            email: contact.emailAddresses.isEmpty ? nil : contact.emailAddresses.map { $0.value as String },
            telephone: contact.phoneNumbers.isEmpty ? nil : contact.phoneNumbers.map { $0.value.stringValue },
            address: address,
            jobTitle: contact.jobTitle.isEmpty ? nil : contact.jobTitle,
            worksFor: contact.organizationName.isEmpty ? nil : Organization(name: contact.organizationName),
            url: contact.urlAddresses.isEmpty ? nil : contact.urlAddresses.map { $0.value as String },
            birthDate: birthDate,
            sameAs: contact.socialProfiles.isEmpty ? nil : contact.socialProfiles.map { $0.value.urlString },
            handles: [Handle(kind: Handle.Kind.appleContacts, value: contact.identifier)],
            contactPoint: contactPoint
        )

        let fullName = CNContactFormatter.string(from: contact, style: .fullName)
        self.name = (fullName?.isEmpty == false) ? fullName : contact.organizationName.isEmpty ? nil : contact.organizationName

        var spouses: [Person] = [], siblings: [Person] = [], children: [Person] = [],
            parents: [Person] = [], others: [Person] = []

        for relation in contact.contactRelations {
            let person = Person(name: relation.value.name)
            outer: if #available(macOS 15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                switch relation.label {
                case CNLabelContactRelationFemalePartner, CNLabelContactRelationHusband,
                     CNLabelContactRelationMalePartner, CNLabelContactRelationPartner,
                     CNLabelContactRelationWife:
                    spouses.append(person)
                case CNLabelContactRelationElderBrother, CNLabelContactRelationElderSibling,
                     CNLabelContactRelationElderSister, CNLabelContactRelationEldestBrother,
                     CNLabelContactRelationEldestSister, CNLabelContactRelationYoungerBrother,
                     CNLabelContactRelationYoungerSibling, CNLabelContactRelationYoungerSister,
                     CNLabelContactRelationYoungestBrother, CNLabelContactRelationYoungestSister,
                     CNLabelContactRelationSibling:
                    siblings.append(person)
                default: break outer
                }
                continue
            }
            switch relation.label {
            case CNLabelContactRelationSpouse: spouses.append(person)
            case CNLabelContactRelationBrother, CNLabelContactRelationSister: siblings.append(person)
            case CNLabelContactRelationChild, CNLabelContactRelationSon,
                 CNLabelContactRelationDaughter: children.append(person)
            case CNLabelContactRelationParent, CNLabelContactRelationMother,
                 CNLabelContactRelationFather: parents.append(person)
            default: others.append(person)
            }
        }

        self.spouse = spouses.isEmpty ? nil : spouses
        self.siblings = siblings.isEmpty ? nil : siblings
        self.children = children.isEmpty ? nil : children
        self.parents = parents.isEmpty ? nil : parents
        self.relatedTo = others.isEmpty ? nil : others
    }

    public func makeCNContact() -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = givenName ?? ""
        contact.familyName = familyName ?? ""
        contact.jobTitle = jobTitle ?? ""
        contact.organizationName = worksFor?.name ?? ""
        contact.emailAddresses = (email ?? []).map {
            CNLabeledValue(label: CNLabelWork, value: $0 as NSString)
        }
        contact.phoneNumbers = (telephone ?? []).map {
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0))
        }
        contact.urlAddresses = (url ?? []).map {
            CNLabeledValue(label: CNLabelWork, value: $0 as NSString)
        }
        return contact
    }
}
#endif
