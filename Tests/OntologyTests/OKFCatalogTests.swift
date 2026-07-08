import Foundation
import Testing
import Ontology
import OntologyOKF

// MARK: - Concept envelope

@Suite("OKF Concept")
struct OKFConceptTests {

    @Test func parsesWebsiteConcept() throws {
        let md = """
        ---
        type: Website
        title: Hacker News
        description: Links for the intellectually curious
        resource: https://news.ycombinator.com
        tags: [tech, news]
        timestamp: 2026-06-30T12:00:00Z
        ---

        Some notes.
        """
        let c = try #require(OKFConcept(id: "items/hn.md", markdown: md))
        #expect(c.type == "Website")
        #expect(c.title == "Hacker News")
        #expect(c.summary == "Links for the intellectually curious")
        #expect(c.resource == URL(string: "https://news.ycombinator.com"))
        #expect(c.tags == ["tech", "news"])
        #expect(c.body == "Some notes.")
    }

    @Test func parsesLocalFileConcept() throws {
        let md = """
        ---
        type: LocalFile
        title: My Doc
        resource: file:///Users/test/doc.pdf
        tags: [docs]
        ---
        """
        let c = try #require(OKFConcept(id: "items/doc.md", markdown: md))
        #expect(c.type == "LocalFile")
        #expect(c.resource?.isFileURL == true)
    }

    @Test func parsesMinimalFrontmatter() throws {
        let c = try #require(OKFConcept(id: "items/min.md", markdown: "---\ntype: Website\n---"))
        #expect(c.title == nil)
        #expect(c.summary == nil)
        #expect(c.resource == nil)
        #expect(c.tags.isEmpty)
    }

    @Test func rejectsMissingFrontmatter() {
        #expect(OKFConcept(id: "x", markdown: "no frontmatter here") == nil)
    }

    /// The strict YAML parser handles a block-style tag list that the old line-based
    /// hand parser silently dropped — the core robustness win of moving onto `Universal`.
    @Test func parsesBlockStyleTags() throws {
        let md = """
        ---
        type: Website
        title: Blocky
        tags:
          - tech
          - news
        ---
        """
        let c = try #require(OKFConcept(id: "items/b.md", markdown: md))
        #expect(c.tags == ["tech", "news"])
    }

    @Test func roundTripsThroughMarkdown() throws {
        var original = OKFConcept(
            id: "items/ex.md", type: "Website", title: "Example", summary: "An example",
            resource: URL(string: "https://example.com"), tags: ["foo", "bar"],
            timestamp: ISO8601DateFormatter().date(from: "2026-06-30T12:00:00Z"),
            body: "Body text."
        )
        original.icon = "flame"
        original.color = "orange"
        original.deletedAt = ISO8601DateFormatter().date(from: "2026-06-01T12:00:00Z")

        let reparsed = try #require(OKFConcept(id: "items/ex.md", markdown: original.markdownString()))
        #expect(reparsed == original)
    }

    @Test func serializesExpectedFieldsInOrder() {
        let c = OKFConcept(
            id: "items/s.md", type: "Website", title: "Snap", summary: "For testing",
            resource: URL(string: "https://example.com"), tags: ["snap"]
        )
        let out = c.markdownString()
        #expect(out.hasPrefix("---\ntype: Website\n"))
        #expect(out.contains("title: Snap"))
        #expect(out.contains("description: For testing"))
        #expect(out.contains("resource: https://example.com"))
        #expect(out.contains("tags: [snap]"))
    }
}

// MARK: - Catalog structure

@Suite("OKF Catalog")
struct OKFCatalogTests {

    private func leaf(_ id: String) -> OKFCatalogNode {
        OKFCatalogNode(concept: OKFConcept(id: "items/\(id).md", title: id))
    }

    /// `[a, b, S[c]]` where S is a concept-backed section.
    private func sampleCatalog() -> OKFCatalog {
        var s = OKFConcept(id: "items/s.md", type: OKFConcept.sectionType, title: "S")
        s.icon = "books.vertical"
        s.color = "blue"
        var section = OKFCatalogNode(concept: s)
        section.children = [leaf("c")]
        return OKFCatalog(outline: [leaf("a"), leaf("b"), section])
    }

    /// serialize → parse reconstructs the same structure, order, ids, and section metadata.
    @Test func serializeParseRoundTrip() throws {
        let catalog = sampleCatalog()
        let out = catalog.serialize()
        let restored = OKFCatalog.parse(indexText: out.indexText, itemFiles: out.itemFiles)

        #expect(restored.outline.map(\.title) == ["a", "b", "S"])
        let section = try #require(restored.outline.last)
        #expect(section.isSection)
        #expect(section.concept?.icon == "books.vertical")
        #expect(section.concept?.color == "blue")
        #expect(section.children.map(\.title) == ["c"])
        // Section concepts are structure, not content.
        #expect(restored.concepts.map(\.id) == ["items/a.md", "items/b.md", "items/c.md"])
    }

    @Test func indexTextRoundTripsUnchanged() {
        let catalog = sampleCatalog()
        let reparsed = catalog.parsing(indexText: catalog.indexText())
        #expect(reparsed.outline.map(\.title) == catalog.outline.map(\.title))
        #expect(reparsed.concepts.map(\.id) == catalog.concepts.map(\.id))
    }

    @Test func editedIndexRestructuresOutline() {
        let edited = """
        # Catalog

        - [c](items/c.md)
        - S
          - [b](items/b.md)
        - [a](items/a.md)
        """
        let outline = sampleCatalog().parsing(indexText: edited).outline
        #expect(outline.map(\.title) == ["c", "S", "a"])
        #expect(outline[1].children.map(\.title) == ["b"])
        #expect(outline[1].isSection)
    }

    @Test func deletedLinesReappendConcepts() {
        let edited = "# Catalog\n\n- [a](items/a.md)\n"
        let outline = sampleCatalog().parsing(indexText: edited).outline
        #expect(outline.first?.title == "a")
        // b and c survive, re-appended at the root.
        #expect(Set(outline.allConcepts.map(\.id))
                == Set(["items/a.md", "items/b.md", "items/c.md"]))
    }

    @Test func unknownLinkPathBecomesSection() {
        let catalog = OKFCatalog(outline: [leaf("a")])
        let outline = catalog.parsing(indexText: "- [Mystery](items/nope.md)").outline
        #expect(outline.first?.isSection == true)
        #expect(outline.first?.title == "Mystery")
    }
}

// MARK: - Trash & decay

@Suite("OKF Catalog Trash")
struct OKFCatalogTrashTests {

    private func leaf(_ id: String) -> OKFCatalogNode {
        OKFCatalogNode(concept: OKFConcept(id: "items/\(id).md", title: id))
    }

    private func trashedLeaf(_ id: String, deleted: Date) -> OKFCatalogNode {
        var c = OKFConcept(id: "items/\(id).md", title: id)
        c.deletedAt = deleted
        return OKFCatalogNode(concept: c)
    }

    @Test func trashRoundTripsThroughSerialize() throws {
        let catalog = OKFCatalog(
            outline: [leaf("a"), leaf("d")],
            trash: [trashedLeaf("b", deleted: Date())]
        )
        let out = catalog.serialize()
        #expect(out.indexText.contains("## Trash"))
        // Trash files are keyed by canonical id and returned separately from live items.
        #expect(out.itemFiles.keys.contains("items/b.md") == false)
        #expect(out.trashFiles.keys.contains("items/b.md") == true)

        let restored = OKFCatalog.parse(
            indexText: out.indexText, itemFiles: out.itemFiles, trashFiles: out.trashFiles)
        #expect(restored.outline.map(\.title) == ["a", "d"])
        #expect(restored.trash.map(\.title) == ["b"])
        #expect(restored.trash.first?.concept?.deletedAt != nil)
    }

    @Test func editingAcrossTrashHeadingMovesItems() {
        let catalog = OKFCatalog(
            outline: [leaf("a")],
            trash: [trashedLeaf("d", deleted: Date())]
        )
        // Restore d (above heading), trash a (below heading).
        let edited = """
        # Catalog

        - [d](items/d.md)

        ## Trash

        - [a](items/a.md)
        """
        let parsed = catalog.parsing(indexText: edited)
        #expect(parsed.outline.map(\.title) == ["d"])
        #expect(parsed.outline.first?.concept?.deletedAt == nil, "restore clears the stamp")
        #expect(parsed.trash.map(\.title) == ["a"])
        #expect(parsed.trash.first?.concept?.deletedAt != nil, "hand-trashed items get stamped")
    }

    @Test func decayPurgesExpiredAndPrunesEmptySections() {
        let old = Date(timeIntervalSinceNow: -40 * 86_400)
        let fresh = Date()
        var s = OKFConcept(id: "items/s.md", type: OKFConcept.sectionType, title: "S")
        s.deletedAt = old
        var section = OKFCatalogNode(concept: s)
        section.children = [trashedLeaf("b", deleted: old)]
        let catalog = OKFCatalog(outline: [], trash: [section, trashedLeaf("a", deleted: fresh)])

        let cutoff = Date(timeIntervalSinceNow: -30 * 86_400)
        let out = catalog.serialize(purgingTrashBefore: cutoff)
        let restored = OKFCatalog.parse(
            indexText: out.indexText, itemFiles: out.itemFiles, trashFiles: out.trashFiles)

        // The 40-day-old section decayed; the fresh item survives.
        #expect(restored.trash.map(\.title) == ["a"])
    }

    /// End-to-end golden round-trip: a mixed live+trash catalog with a concept-backed
    /// section survives serialize → parse structurally intact.
    @Test func goldenRoundTrip() throws {
        var a = OKFConcept(id: "items/a.md", type: "Website", title: "Alpha",
                           resource: URL(string: "https://a.example"), tags: ["x", "y"])
        a.timestamp = ISO8601DateFormatter().date(from: "2026-06-30T12:00:00Z")

        var s = OKFConcept(id: "items/s.md", type: OKFConcept.sectionType, title: "Section")
        s.icon = "folder"; s.color = "green"
        var section = OKFCatalogNode(concept: s)
        section.children = [
            OKFCatalogNode(concept: OKFConcept(id: "items/b.md", title: "Beta")),
            OKFCatalogNode(concept: OKFConcept(id: "items/c.md", title: "Gamma")),
        ]

        var e = OKFConcept(id: "items/e.md", title: "Deleted")
        e.deletedAt = ISO8601DateFormatter().date(from: "2026-06-01T12:00:00Z")

        let catalog = OKFCatalog(
            outline: [OKFCatalogNode(concept: a), section],
            trash: [OKFCatalogNode(concept: e)]
        )

        let out = catalog.serialize()
        let r = OKFCatalog.parse(
            indexText: out.indexText, itemFiles: out.itemFiles, trashFiles: out.trashFiles)

        #expect(r.outline.map(\.title) == ["Alpha", "Section"])
        let ra = try #require(r.outline.first?.concept)
        #expect(ra.resource == URL(string: "https://a.example"))
        #expect(ra.tags == ["x", "y"])
        #expect(ra.timestamp == a.timestamp)

        let rsection = try #require(r.outline.last)
        #expect(rsection.isSection)
        #expect(rsection.concept?.icon == "folder")
        #expect(rsection.concept?.color == "green")
        #expect(rsection.children.map(\.title) == ["Beta", "Gamma"])

        #expect(r.trash.map(\.title) == ["Deleted"])
        #expect(r.trash.first?.concept?.deletedAt == e.deletedAt)
    }
}

// MARK: - Extras preservation & typed entities

@Suite("OKF Concept Extras")
struct OKFConceptExtrasTests {

    @Test func preservesUnknownFrontmatterKeys() throws {
        let md = """
        ---
        type: Place
        title: The Rusty Flagon
        id: place.inn01
        address: 42 Market Street
        geo:
          latitude: 40.7
          longitude: -74.0
        ---
        A cozy inn.
        """
        let c = try #require(OKFConcept(id: "items/inn.md", markdown: md))
        #expect(c.type == "Place")
        #expect(c.title == "The Rusty Flagon")
        #expect(c.extras["id"]?.string == "place.inn01")
        #expect(c.extras["address"]?.string == "42 Market Street")
        #expect(c.extras["geo"]?.object != nil)

        // Re-emitting keeps the extension keys and their nested structure.
        let reparsed = try #require(OKFConcept(id: "items/inn.md", markdown: c.markdownString()))
        #expect(reparsed.extras["address"]?.string == "42 Market Street")
        #expect(reparsed.extras["geo"]?.object?["latitude"]?.number == 40.7)
        #expect(reparsed.body == "A cozy inn.")
    }

    @Test func typedEntityRoundTrip() throws {
        let person = Person(identifier: "person.jane", givenName: "Jane", familyName: "Smith")
        let concept = try OKFConcept(id: "items/jane.md", entity: person, body: "Runs the inn.")
        #expect(concept.type == "Person")
        #expect(concept.title == "Jane Smith")
        #expect(concept.body == "Runs the inn.")

        // Structured fields ride in `extras` and are recoverable by decoding back to the entity.
        let recovered = try concept.decode(Person.self)
        #expect(recovered.givenName == "Jane")
        #expect(recovered.familyName == "Smith")
        #expect(recovered.identifier == "person.jane")
    }

    @Test func typedEntitySurvivesCatalogRoundTrip() throws {
        let place = Place(identifier: "place.inn01", name: "The Rusty Flagon", description: "A cozy inn")
        let concept = try OKFConcept(id: "items/inn.md", entity: place)
        let catalog = OKFCatalog(outline: [OKFCatalogNode(concept: concept)])

        let out = catalog.serialize()
        let restored = OKFCatalog.parse(indexText: out.indexText, itemFiles: out.itemFiles)
        let recovered = try #require(restored.concepts.first).decode(Place.self)
        #expect(recovered.identifier == "place.inn01")
        #expect(recovered.name == "The Rusty Flagon")
        #expect(recovered.description == "A cozy inn")
    }
}
