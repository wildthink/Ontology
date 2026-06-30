#if canImport(Contacts)
import Contacts
import Ontology

extension Organization {
    public init?(_ contact: CNContact) {
        guard contact.contactType == .organization else { return nil }
        self.init(
            identifier: contact.identifier,
            name: contact.organizationName.isEmpty ? nil : contact.organizationName,
            address: contact.postalAddresses.isEmpty ? nil : contact.postalAddresses.map { PostalAddress($0.value) },
            email: contact.emailAddresses.isEmpty ? nil : contact.emailAddresses.map { $0.value as String },
            telephone: contact.phoneNumbers.isEmpty ? nil : contact.phoneNumbers.map { $0.value.stringValue },
            url: contact.urlAddresses.isEmpty ? nil : contact.urlAddresses.map { $0.value as String },
            handles: [Handle(kind: Handle.Kind.appleContacts, value: contact.identifier)]
        )
    }
}
#endif
