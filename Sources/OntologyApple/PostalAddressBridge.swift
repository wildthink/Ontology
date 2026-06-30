#if canImport(Contacts)
import Contacts
import Ontology

extension PostalAddress {
    public init(_ address: CNPostalAddress) {
        self.init(
            streetAddress: address.street.isEmpty ? nil : address.street,
            addressLocality: address.city.isEmpty ? nil : address.city,
            addressRegion: address.state.isEmpty ? nil : address.state,
            postalCode: address.postalCode.isEmpty ? nil : address.postalCode,
            addressCountry: address.country.isEmpty ? nil : address.country
        )
    }
}
#endif
