import Foundation
import Testing

@testable import Ontology

@Suite
struct MarkdownWriterTests {

    @Test("Person serialises to YAML frontmatter with correct keys")
    func testPersonFrontmatter() throws {
        let person = Person(
            identifier: "person.3f8a91b2",
            givenName: "Jane",
            familyName: "Smith"
        )
        let doc = try MarkdownDocument(person, body: "Jane has run The Rusty Flagon for thirty years.")
        let text = doc.string()

        #expect(text.hasPrefix("---\n"))
        #expect(text.contains("taxon: person"))
        #expect(text.contains("id: person.3f8a91b2"))
        #expect(text.contains("givenName: Jane"))
        #expect(text.contains("familyName: Smith"))
        #expect(text.contains("Jane has run The Rusty Flagon"))
        #expect(!text.contains("@context"))
        #expect(!text.contains("@type"))
        #expect(!text.contains("@id"))
    }

    @Test("Plan serialises rrule and tags correctly")
    func testPlanFrontmatter() throws {
        let plan = Plan(
            identifier: "plan.abc12345",
            name: "Weekly Game",
            rrule: "FREQ=WEEKLY;BYDAY=FR",
            tags: ["campaign", "weekly"]
        )
        let doc = try MarkdownDocument(plan)
        let text = doc.string()

        #expect(text.contains("taxon: plan"))
        #expect(text.contains("id: plan.abc12345"))
        #expect(text.contains("name: Weekly Game"))
        #expect(text.contains("rrule:"))
        #expect(text.contains("FREQ=WEEKLY;BYDAY=FR"))
        #expect(text.contains("tags:"))
        #expect(text.contains("campaign"))
    }

    @Test("Place serialises nested geo coordinates")
    func testPlaceWithGeo() throws {
        let place = Place(
            identifier: "place.inn01",
            name: "The Rusty Flagon",
            geo: GeoCoordinates(latitude: 37.7694, longitude: -122.4862)
        )
        let doc = try MarkdownDocument(place)
        let text = doc.string()

        #expect(text.contains("taxon: place"))
        #expect(text.contains("name: The Rusty Flagon"))
        #expect(text.contains("geo:"))
        #expect(text.contains("latitude:"))
        #expect(text.contains("longitude:"))
    }

    @Test("Full round-trip: write then read back a Person")
    func testPersonRoundTrip() throws {
        let original = Person(
            identifier: "person.3f8a91b2",
            givenName: "Jane",
            familyName: "Smith",
            jobTitle: "Innkeeper"
        )
        let doc = try MarkdownDocument(original, body: "A skilled innkeeper.")
        let text = doc.string()

        // Read back
        let parsed = MarkdownDocument(string: text)
        let recovered = try parsed.decode(Person.self)

        #expect(recovered.identifier == original.identifier)
        #expect(recovered.givenName == original.givenName)
        #expect(recovered.familyName == original.familyName)
        #expect(recovered.jobTitle == original.jobTitle)
        #expect(parsed.body == "A skilled innkeeper.")
    }

    @Test("Full round-trip: write then read back a Plan")
    func testPlanRoundTrip() throws {
        let original = Plan(
            identifier: "plan.abc12345",
            name: "Dragon Arc",
            description: "The main arc",
            rrule: "FREQ=WEEKLY;BYDAY=SA"
        )
        let doc = try MarkdownDocument(original, body: "The party hunts a dragon.")
        let text = doc.string()

        let parsed = MarkdownDocument(string: text)
        let recovered = try parsed.decode(Plan.self)

        #expect(recovered.identifier == original.identifier)
        #expect(recovered.name == original.name)
        #expect(recovered.rrule == original.rrule)
    }

    @Test("string() produces valid fenced frontmatter structure")
    func testFenceStructure() throws {
        let place = Place(name: "Evermore")
        let doc = try MarkdownDocument(place, body: "A city of wonder.")
        let text = doc.string()

        let lines = text.components(separatedBy: "\n")
        #expect(lines.first == "---")
        #expect(lines.filter { $0 == "---" }.count == 2)
        #expect(text.contains("\n---\n"))
    }

    @Test("Document with no body omits trailing newlines")
    func testNoBody() throws {
        let person = Person(givenName: "Alice")
        let doc = try MarkdownDocument(person)
        let text = doc.string()
        #expect(!text.hasSuffix("\n\n"))
    }

    @Test("Strings with colons are quoted")
    func testSpecialStringQuoting() throws {
        let record = Record(
            name: "Session: The Beginning",
            outcome: "Heroes won: all enemies defeated"
        )
        let doc = try MarkdownDocument(record)
        let text = doc.string()
        // Strings with colons must be quoted in YAML
        #expect(text.contains("\"Session: The Beginning\""))
        #expect(text.contains("\"Heroes won: all enemies defeated\""))
    }
}
