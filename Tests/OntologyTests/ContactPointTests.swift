import OntologyApple
import Testing

@testable import Ontology

#if canImport(Contacts)
    import Contacts
#endif

@Suite
struct ContactPointTests {
    @Test("Basic initialization works correctly")
    func testBasicInitialization() throws {
        let contactPoint = ContactPoint(contactType: "email", identifier: "test@example.com")
        #expect(contactPoint.contactType == "email")
        #expect(contactPoint.identifier == "test@example.com")
    }

    @Test("Encoding includes all required fields and no JSON-LD framing")
    func testEncoding() throws {
        let contactPoint = ContactPoint(contactType: "phone", identifier: "+1-555-123-4567")

        let encoder = JSONEncoder()
        let data = try encoder.encode(contactPoint)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["@context"] == nil)
        #expect(json["@type"] == nil)
        #expect(json["contactType"] as? String == "phone")
        #expect(json["identifier"] as? String == "+1-555-123-4567")
    }

    @Test("JSON-LD decoding works with valid input")
    func testJSONLDDecoding() throws {
        let jsonString = """
            {
                "@context": "https://schema.org",
                "@type": "ContactPoint",
                "contactType": "telegram",
                "identifier": "@username"
            }
            """

        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let contactPoint = try decoder.decode(ContactPoint.self, from: data)

        #expect(contactPoint.contactType == "telegram")
        #expect(contactPoint.identifier == "@username")
    }

    /// Value types carry no type tag of their own — the field that holds them
    /// determines what they are. A stray `@type` from a wild-web record is
    /// data the hub does not model, so it is ignored rather than rejected.
    /// Type checking for *entities* lives at the boundaries: `taxon` on the
    /// frontmatter path, `SchemaTypeRegistry` routing on the JSON-LD path.
    @Test("A foreign @type is ignored rather than rejected")
    func testForeignTypeIsIgnored() throws {
        let jsonString = """
            {
                "@context": "https://schema.org",
                "@type": "WrongType",
                "contactType": "telegram",
                "identifier": "@username"
            }
            """

        let data = jsonString.data(using: .utf8)!
        let contactPoint = try JSONDecoder().decode(ContactPoint.self, from: data)

        #expect(contactPoint.contactType == "telegram")
    }

    #if canImport(Contacts)
        @Test("CNInstantMessageAddress initialization works correctly")
        func testCNInstantMessageAddressInitialization() throws {
            let imAddress = CNInstantMessageAddress(username: "johndoe", service: "skype")
            let contactPoint = ContactPoint(imAddress)

            #expect(contactPoint.contactType == "skype")
            #expect(contactPoint.identifier == "johndoe")
        }
    #endif
}
