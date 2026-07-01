import Foundation
import Testing

@testable import Ontology
import OntologyOKF

/// Round-trip tests for `Topic`, `Relationship`, `Artifact`, and `Media` —
/// the second wave of standalone hub types added alongside `Outline`.
@Suite
struct CatalogTypesTests {

    // MARK: - Topic

    @Test("Topic basic init and taxon")
    func testTopicInit() {
        let topic = Topic(
            identifier: "topic.old-war",
            name: "The Old War",
            description: "The war that ended the Third Age",
            relatedTopics: [.entity(.topic, "topic.third-age")],
            tags: ["history"]
        )
        #expect(topic.taxon == .topic)
        #expect(topic.relatedTopics?.count == 1)
    }

    @Test("Topic round-trips through OKF markdown")
    func testTopicOKFRoundTrip() throws {
        let original = Topic(
            identifier: "topic.old-war",
            name: "The Old War",
            description: "The war that ended the Third Age",
            tags: ["history"]
        )
        let doc = try OKFDocument(original)
        let decoded = try OKFReader.decode(Topic.self, from: doc.string())
        #expect(decoded.name == original.name)
        #expect(decoded.description == original.description)
        #expect(decoded.tags == original.tags)
    }

    // MARK: - Relationship

    @Test("Relationship basic init and taxon")
    func testRelationshipInit() {
        let rel = Relationship(
            identifier: "relationship.mentor01",
            from: .entity(.person, "person.3f8a91b2"),
            to: .entity(.person, "person.player01"),
            kind: "mentor",
            reciprocal: false,
            note: "Since the campaign's second arc"
        )
        #expect(rel.taxon == .relationship)
        #expect(rel.reciprocal == false)
    }

    @Test("Relationship round-trips through OKF markdown")
    func testRelationshipOKFRoundTrip() throws {
        let original = Relationship(
            identifier: "relationship.mentor01",
            from: .entity(.person, "person.3f8a91b2"),
            to: .entity(.person, "person.player01"),
            kind: "mentor",
            reciprocal: false,
            note: "Since the campaign's second arc"
        )
        let doc = try OKFDocument(original)
        let decoded = try OKFReader.decode(Relationship.self, from: doc.string())
        #expect(decoded.from == original.from)
        #expect(decoded.to == original.to)
        #expect(decoded.kind == original.kind)
        #expect(decoded.reciprocal == original.reciprocal)
        #expect(decoded.note == original.note)
    }

    // MARK: - Artifact

    @Test("Artifact basic init and taxon")
    func testArtifactInit() {
        let artifact = Artifact(
            identifier: "artifact.evermore-blade",
            name: "The Evermore Blade",
            owner: .entity(.person, "person.3f8a91b2"),
            media: .entity(.media, "media.evermore-blade-photo"),
            tags: ["weapon", "magic"]
        )
        #expect(artifact.taxon == .artifact)
        #expect(artifact.tags == ["weapon", "magic"])
    }

    @Test("Artifact round-trips through OKF markdown")
    func testArtifactOKFRoundTrip() throws {
        let original = Artifact(
            identifier: "artifact.evermore-blade",
            name: "The Evermore Blade",
            description: "Forged in the Old War",
            owner: .entity(.person, "person.3f8a91b2"),
            media: .entity(.media, "media.evermore-blade-photo"),
            tags: ["weapon", "magic"]
        )
        let doc = try OKFDocument(original, body: "Said to sing when drawn near danger.")
        let decoded = try OKFReader.decode(Artifact.self, from: doc.string())
        #expect(decoded.name == original.name)
        #expect(decoded.description == original.description)
        #expect(decoded.owner == original.owner)
        #expect(decoded.media == original.media)
        #expect(decoded.tags == original.tags)
    }

    // MARK: - Media

    @Test("Media basic init and taxon")
    func testMediaInit() {
        let media = Media(
            identifier: "media.evermore-map01",
            name: "Map of Evermore",
            contentUrl: URL(string: "https://example.com/maps/evermore.png")!,
            encodingFormat: "image/png",
            credit: "Cartography by Jane Smith"
        )
        #expect(media.taxon == .media)
        #expect(media.encodingFormat == "image/png")
    }

    @Test("Media round-trips through OKF markdown")
    func testMediaOKFRoundTrip() throws {
        let original = Media(
            identifier: "media.evermore-map01",
            name: "Map of Evermore",
            contentUrl: URL(string: "https://example.com/maps/evermore.png")!,
            encodingFormat: "image/png",
            credit: "Cartography by Jane Smith"
        )
        let doc = try OKFDocument(original)
        let decoded = try OKFReader.decode(Media.self, from: doc.string())
        #expect(decoded.name == original.name)
        #expect(decoded.contentUrl == original.contentUrl)
        #expect(decoded.encodingFormat == original.encodingFormat)
        #expect(decoded.credit == original.credit)
    }
}
