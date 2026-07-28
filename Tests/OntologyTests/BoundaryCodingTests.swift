import Foundation
import Testing
import Universal

@testable import Ontology

/// Hub types encode plain JSON — field names, `id`, no `@`-prefixed keys.
/// Everything JSON-LD lives at a boundary: `JSONLD` writes it, and
/// `SchemaTypeRegistry` reads it. These tests pin that split down.
@Suite("Boundary coding")
struct BoundaryCodingTests {

    // MARK: - Hub-native shape

    @Test("No hub type emits JSON-LD framing keys")
    func testNoFramingInHubOutput() throws {
        let place = Place(
            identifier: "place.001",
            name: "The Rusty Flagon",
            address: PostalAddress(streetAddress: "1 Main St"),
            geo: GeoCoordinates(latitude: 1, longitude: 2)
        )
        let occurrence = Occurrence(identifier: "occurrence.001", name: "Session One")
        let person = Person(identifier: "person.001", givenName: "Jane")

        let entities: [any Entity] = [place, occurrence, person]
        for entity in entities {
            let data = try JSONEncoder().encode(entity)
            let text = String(data: data, encoding: .utf8)!
            #expect(!text.contains("@context"))
            #expect(!text.contains("@type"))
            #expect(!text.contains("@id"))
        }
    }

    @Test("identifier round-trips through the `id` key")
    func testIdentifierRoundTrip() throws {
        let original = Occurrence(identifier: "occurrence.abc12345", name: "Session One")
        let data = try JSONEncoder().encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["id"] as? String == "occurrence.abc12345")

        let decoded = try JSONDecoder().decode(Occurrence.self, from: data)
        #expect(decoded.identifier == "occurrence.abc12345")
    }

    // MARK: - Markdown boundary

    @Test("Frontmatter round-trips a plan, identifier included")
    func testFrontmatterRoundTrip() throws {
        let plan = Plan(
            identifier: "plan.abc12345",
            name: "Campaign Kickoff",
            status: Plan.Status.active,
            tags: ["intro"]
        )
        let text = try MarkdownDocument(plan, body: "Notes").string()

        #expect(text.contains("taxon: plan"))
        #expect(text.contains("id: plan.abc12345"))
        #expect(!text.contains("@type"))
        #expect(!text.contains("@id"))

        let decoded = try MarkdownDocument(string: text).decode(Plan.self)
        #expect(decoded.identifier == "plan.abc12345")
        #expect(decoded.name == "Campaign Kickoff")
        #expect(decoded.status == "active")
        #expect(decoded.tags == ["intro"])
    }

    /// The type check `@type` used to perform inside every decoder now lives
    /// on the frontmatter path, keyed on the hub's own `taxon`.
    @Test("A mismatched taxon is rejected")
    func testTaxonMismatchRejected() {
        let frontmatter = """
            taxon: person
            id: person.001
            name: Jane
            """
        #expect(throws: (any Error).self) {
            try FrontmatterParser.decode(Place.self, from: frontmatter)
        }
    }

    @Test("A matching taxon decodes")
    func testTaxonMatchAccepted() throws {
        let frontmatter = """
            taxon: place
            id: place.001
            name: The Rusty Flagon
            """
        let place = try FrontmatterParser.decode(Place.self, from: frontmatter)

        #expect(place.identifier == "place.001")
        #expect(place.name == "The Rusty Flagon")
    }

    @Test("Frontmatter with no taxon still decodes")
    func testTaxonOptional() throws {
        let place = try FrontmatterParser.decode(Place.self, from: "name: Nameless")
        #expect(place.name == "Nameless")
    }

    /// Files written before the framing moved out of the types carry `@id`.
    @Test("Legacy @id frontmatter still reads")
    func testLegacyFrontmatterIdentifier() throws {
        let frontmatter = """
            taxon: place
            "@id": place.legacy
            name: Old File
            """
        let place = try FrontmatterParser.decode(Place.self, from: frontmatter)

        #expect(place.identifier == "place.legacy")
    }

    // MARK: - JSON-LD boundary

    @Test("JSONLD.object frames an entity and its nested values")
    func testJSONLDFraming() throws {
        let place = Place(
            identifier: "place.001",
            name: "The Rusty Flagon",
            address: PostalAddress(streetAddress: "1 Main St"),
            geo: GeoCoordinates(latitude: 1, longitude: 2)
        )
        let json = try JSONLD.object(place)

        #expect(json["@context"]?.string == "https://schema.org")
        #expect(json["@type"]?.string == "Place")
        #expect(json["@id"]?.string == "place.001")
        #expect(json["id"] == nil)
        #expect(json["geo"]?.object?["@type"]?.string == "GeoCoordinates")
        #expect(json["address"]?.object?["@type"]?.string == "PostalAddress")
    }

    @Test("JSONLD.object leaves meta untouched")
    func testJSONLDLeavesMetaAlone() throws {
        var document = Document(identifier: "document.001", name: "Notes")
        document.meta = ["nested": .object(["id": .string("not-an-entity")])]

        let json = try JSONLD.object(document)
        let nested = json["meta"]?.object?["nested"]?.object

        #expect(nested?["id"]?.string == "not-an-entity")
        #expect(nested?["@id"] == nil)
        #expect(nested?["@type"] == nil)
    }

    @Test("Wild-web @id lands on identifier as `id`")
    func testRegistryMapsAtIdToIdentifier() throws {
        let record = """
            {"@context": "https://schema.org", "@type": "Person",
             "@id": "https://example.com/#jane", "givenName": "Jane"}
            """
        let entity = SchemaTypeRegistry.entity(fromJSONLD: try JSON.parse(Data(record.utf8)))

        let person = try #require(entity as? Person)
        #expect(person.identifier == "https://example.com/#jane")
        #expect(person.givenName == "Jane")
    }

    @Test("A junk url does not sink an otherwise good record")
    func testLenientURL() throws {
        let record = #"{"@type": "Place", "name": "Somewhere", "url": ""}"#
        let entity = SchemaTypeRegistry.entity(fromJSONLD: try JSON.parse(Data(record.utf8)))

        let place = try #require(entity as? Place)
        #expect(place.name == "Somewhere")
        #expect(place.url == nil)
    }
}
