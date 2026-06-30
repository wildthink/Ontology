import Foundation
import Testing

@testable import Ontology

@Suite
struct MarkdownDocumentTests {

    @Test("Parses frontmatter and body correctly")
    func testBasicParsing() {
        let md = MarkdownDocument(string: """
        ---
        taxon: person
        givenName: Jane
        familyName: Smith
        ---

        Jane has run The Rusty Flagon for thirty years.
        """)

        #expect(md.frontmatter.contains("givenName: Jane"))
        #expect(md.frontmatter.contains("familyName: Smith"))
        #expect(md.body.contains("Rusty Flagon"))
        #expect(!md.body.contains("---"))
    }

    @Test("Returns empty frontmatter for files without fence")
    func testNoFrontmatter() {
        let md = MarkdownDocument(string: "Just some markdown with no frontmatter.")
        #expect(md.frontmatter.isEmpty)
        #expect(md.body == "Just some markdown with no frontmatter.")
    }

    @Test("Handles unclosed frontmatter fence gracefully")
    func testUnclosedFence() {
        let md = MarkdownDocument(string: """
        ---
        taxon: place
        name: Evermore
        """)
        #expect(md.frontmatter.isEmpty)
    }
}

@Suite
struct FrontmatterParserTests {

    @Test("Decodes a simple Person from YAML frontmatter")
    func testDecodePersonFromYAML() throws {
        let yaml = """
        givenName: Jane
        familyName: Smith
        """
        let person = try FrontmatterParser.decode(Person.self, from: yaml)
        #expect(person.givenName == "Jane")
        #expect(person.familyName == "Smith")
    }

    @Test("Decodes a Place with nested geo from YAML frontmatter")
    func testDecodePlaceFromYAML() throws {
        let yaml = """
        name: The Rusty Flagon
        telephone: "555-1234"
        """
        let place = try FrontmatterParser.decode(Place.self, from: yaml)
        #expect(place.name == "The Rusty Flagon")
        #expect(place.telephone == "555-1234")
    }

    @Test("Decodes a Plan with rrule from YAML frontmatter")
    func testDecodePlanFromYAML() throws {
        let yaml = """
        name: Weekly Game Session
        rrule: "FREQ=WEEKLY;BYDAY=FR"
        """
        let plan = try FrontmatterParser.decode(Plan.self, from: yaml)
        #expect(plan.name == "Weekly Game Session")
        #expect(plan.rrule == "FREQ=WEEKLY;BYDAY=FR")
    }
}

@Suite
struct WikiLinkScannerTests {

    @Test("Finds entity refs in markdown body")
    func testEntityRefs() {
        let text = "Jane (see [[person.3f8a91b2]]) knows [[org.4c2d7e1a]]."
        let refs = WikiLinkScanner.scan(text)
        #expect(refs.count == 2)
        #expect(refs[0] == .entity(Taxon("person"), "3f8a91b2"))
        #expect(refs[1] == .entity(Taxon("org"), "4c2d7e1a"))
    }

    @Test("Finds path refs for asset links")
    func testPathRefs() {
        let text = "Portrait: [[./assets/portrait.jpg]]"
        let refs = WikiLinkScanner.scan(text)
        #expect(refs.count == 1)
        #expect(refs[0] == .path("./assets/portrait.jpg"))
    }

    @Test("Returns empty array for text with no wikilinks")
    func testNoLinks() {
        let refs = WikiLinkScanner.scan("No links here at all.")
        #expect(refs.isEmpty)
    }

    @Test("End-to-end: scan wikilinks from MarkdownDocument body")
    func testEndToEnd() {
        let md = MarkdownDocument(string: """
        ---
        taxon: record
        name: Session 1
        ---

        Jane (see [[person.3f8a91b2]]) arrived at [[place.inn01]].
        """)
        let refs = md.wikilinks
        #expect(refs.count == 2)
        #expect(refs.contains(.entity(Taxon("person"), "3f8a91b2")))
        #expect(refs.contains(.entity(Taxon("place"), "inn01")))
    }
}
