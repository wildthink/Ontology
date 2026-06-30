#if canImport(Contacts)
import Contacts
import Ontology

extension ContactPoint {
    public init(_ im: CNInstantMessageAddress) {
        self.init(contactType: im.service, identifier: im.username)
    }
}
#endif
