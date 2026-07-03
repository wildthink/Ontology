import Foundation
import Testing

@testable import Ontology
import OntologyOKF

/// Tests for the `meta` open-metadata bag, the `Document` type, and
/// `SchemaTypeRegistry` JSON-LD decoding — the Phase 1 schema additions
/// for the Luxo integration.
@Suite
struct MetaAndDocumentTests {

    // MARK: - meta round-trip

    @Test("meta round-trips through OKF markdown with nested values")
    func testMetaOKFRoundTrip() throws {
        var person = Person(givenName: "Jane", familyName: "Smith")
        person.identifier = "person.3f8a91b2"
        person.meta = [
            "kMDItemPixelWidth": 1920,
            "imageDataAvailable": true,
            "score": 0.87,
            "labels": ["friend", "player"],
            "nested": ["a": 1, "b": "two"],
        ]

        let doc = try OKFDocument(person)
        let text = doc.string()
        #expect(text.contains("meta:"))

        let decoded = try OKFReader.decode(Person.self, from: text)
        #expect(decoded.meta?["kMDItemPixelWidth"] == 1920)
        #expect(decoded.meta?["imageDataAvailable"] == true)
        #expect(decoded.meta?["labels"] == ["friend", "player"])
        #expect(decoded.meta?["nested"] == ["a": 1, "b": "two"])
    }

    @Test("meta is omitted from frontmatter when nil")
    func testNilMetaOmitted() throws {
        var topic = Topic(name: "The Old War")
        topic.identifier = "topic.old-war"
        let doc = try OKFDocument(topic)
        #expect(!doc.string().contains("meta:"))
    }

    @Test("meta round-trips through JSON-LD encoding")
    func testMetaJSONRoundTrip() throws {
        var plan = Plan(name: "Session prep")
        plan.identifier = "plan.3f8a91b2"
        plan.meta = ["origin": "gcal", "sequence": 3]

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)
        #expect(decoded.meta?["origin"] == "gcal")
        #expect(decoded.meta?["sequence"] == 3)
    }

    // MARK: - Document

    @Test("Document basic init and taxon")
    func testDocumentInit() {
        let doc = Document(
            identifier: "document.9a2f11c4",
            name: "Session Notes.pdf",
            url: URL(string: "file:///Users/jane/Notes/Session%20Notes.pdf"),
            contentType: "com.adobe.pdf",
            size: 48_213,
            meta: ["kMDItemPageCount": 12]
        )
        #expect(doc.taxon == .document)
        #expect(doc.id == "document.9a2f11c4")
    }

    @Test("Document round-trips through OKF markdown")
    func testDocumentOKFRoundTrip() throws {
        let original = Document(
            identifier: "document.9a2f11c4",
            name: "Session Notes.pdf",
            description: "Prep notes for session 12",
            url: URL(string: "file:///Users/jane/Notes/Session%20Notes.pdf"),
            contentType: "com.adobe.pdf",
            size: 48_213,
            handles: [Handle(kind: Handle.Kind.appleSpotlight, value: "/Users/jane/Notes/Session Notes.pdf")],
            meta: ["kMDItemPageCount": 12, "kMDItemAuthors": ["Jane Smith"]]
        )
        let doc = try OKFDocument(original)
        let decoded = try OKFReader.decode(Document.self, from: doc.string())
        #expect(decoded.name == original.name)
        #expect(decoded.url == original.url)
        #expect(decoded.contentType == original.contentType)
        #expect(decoded.size == original.size)
        #expect(decoded.handles?.value(for: Handle.Kind.appleSpotlight) != nil)
        #expect(decoded.meta?["kMDItemPageCount"] == 12)
        #expect(decoded.meta?["kMDItemAuthors"] == ["Jane Smith"])
    }

    // MARK: - SchemaTypeRegistry

    @Test("JSON-LD Person decodes to hub Person")
    func testRegistryPerson() throws {
        let json: JSON = .object([
            "@context": "https://schema.org",
            "@type": "Person",
            "givenName": "Jane",
            "familyName": "Smith",
            "email": .array(["jane@example.com"]),
        ])
        let entity = SchemaTypeRegistry.entity(fromJSONLD: json, sourceURL: URL(string: "https://example.com/about"))
        let person = try #require(entity as? Person)
        #expect(person.givenName == "Jane")
        #expect(person.familyName == "Smith")
        #expect(person.handles?.value(for: Handle.Kind.webPage) == "https://example.com/about")
    }

    @Test("JSON-LD Event decodes to hub Occurrence")
    func testRegistryEvent() throws {
        let json: JSON = .object([
            "@type": "MusicEvent",
            "name": "Midsummer Concert",
            "startDate": "2026-07-04T19:00:00Z",
            "location": "Town Green",
        ])
        let entity = SchemaTypeRegistry.entity(fromJSONLD: json)
        let occurrence = try #require(entity as? Occurrence)
        #expect(occurrence.name == "Midsummer Concert")
        #expect(occurrence.startDate != nil)
    }

    @Test("URL-form and array-form @type resolve")
    func testRegistryTypeNormalization() throws {
        let urlForm: JSON = .object(["@type": "https://schema.org/Person", "givenName": "Jane"])
        #expect(SchemaTypeRegistry.entity(fromJSONLD: urlForm) is Person)

        let arrayForm: JSON = .object(["@type": .array(["Person", "Author"]), "givenName": "Jane"])
        #expect(SchemaTypeRegistry.entity(fromJSONLD: arrayForm) is Person)
    }

    @Test("Unmapped @type falls back to Document preserving raw record")
    func testRegistryFallback() throws {
        let json: JSON = .object([
            "@type": "NewsArticle",
            "headline": "Dragon Sighted Over Evermore",
            "description": "Local farmers report a winged shadow.",
            "datePublished": "2026-06-30",
        ])
        let entity = SchemaTypeRegistry.entity(fromJSONLD: json, sourceURL: URL(string: "https://example.com/news/1"))
        let document = try #require(entity as? Document)
        #expect(document.name == "Dragon Sighted Over Evermore")
        #expect(document.meta?["schemaType"] == "NewsArticle")
        #expect(document.meta?["jsonld"]?.object?["datePublished"] == "2026-06-30")
        #expect(document.handles?.value(for: Handle.Kind.webPage) == "https://example.com/news/1")
    }

    @Test("Typed decode failure falls back to Document, not an error")
    func testRegistryDecodeFailureFallsBack() throws {
        // startDate that ISO8601 cannot parse forces Occurrence decode to fail
        let json: JSON = .object([
            "@type": "Event",
            "name": "Vague Gathering",
            "startDate": "sometime next summer",
        ])
        let entity = SchemaTypeRegistry.entity(fromJSONLD: json)
        let document = try #require(entity as? Document)
        #expect(document.name == "Vague Gathering")
    }
}
