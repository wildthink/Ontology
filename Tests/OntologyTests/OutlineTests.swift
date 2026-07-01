import Foundation
import Testing

@testable import Ontology
import OntologyOKF

@Suite
struct OutlineTests {

    @Test("Basic initialization with nested nodes")
    func testBasicInit() {
        let outline = Outline(
            identifier: "outline.toc",
            name: "Campaign Table of Contents",
            nodes: [
                OutlineNode(
                    title: "Act I — The Dragon Arc",
                    note: "Introduces the goblin lair",
                    children: [
                        OutlineNode(title: "Session 1", ref: .entity(.occurrence, "occurrence.s01")),
                        OutlineNode(title: "Session 2", ref: .entity(.occurrence, "occurrence.s02")),
                    ]
                ),
                OutlineNode(title: "Act II — The Siege", tags: ["climax"]),
            ]
        )
        #expect(outline.taxon == .outline)
        #expect(outline.nodes.count == 2)
        #expect(outline.nodes[0].children.count == 2)
        #expect(outline.nodes[0].children[0].ref == .entity(.occurrence, "occurrence.s01"))
        #expect(outline.nodes[1].tags == ["climax"])
    }

    @Test("Empty nodes by default")
    func testDefaultNodes() {
        let outline = Outline(name: "Empty Outline")
        #expect(outline.nodes.isEmpty)
    }

    @Test("JSON-LD round-trip preserves hierarchy and node metadata")
    func testJSONRoundTrip() throws {
        let original = Outline(
            identifier: "outline.toc",
            name: "Campaign Table of Contents",
            nodes: [
                OutlineNode(
                    title: "Act I",
                    note: "Introduces the goblin lair",
                    tags: ["arc"],
                    children: [
                        OutlineNode(title: "Session 1", ref: .entity(.occurrence, "occurrence.s01")),
                    ]
                ),
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Outline.self, from: data)

        #expect(decoded.identifier == original.identifier)
        #expect(decoded.name == original.name)
        #expect(decoded.nodes == original.nodes)
        #expect(decoded.nodes[0].children[0].ref == .entity(.occurrence, "occurrence.s01"))
    }

    @Test("Outline round-trips through OKF markdown")
    func testOKFRoundTrip() throws {
        let original = Outline(
            identifier: "outline.toc",
            name: "Campaign Table of Contents",
            description: "Session order for the Dragon Arc",
            nodes: [
                OutlineNode(
                    title: "Act I",
                    note: "Introduces the goblin lair",
                    children: [
                        OutlineNode(title: "Session 1", ref: .entity(.occurrence, "occurrence.s01")),
                    ]
                ),
            ]
        )
        let doc = try OKFDocument(original)
        let text = doc.string()
        #expect(text.contains("type: Outline"))
        #expect(text.contains("title: Campaign Table of Contents"))

        let decoded = try OKFReader.decode(Outline.self, from: text)
        #expect(decoded.name == original.name)
        #expect(decoded.description == original.description)
        #expect(decoded.nodes == original.nodes)
    }

    @Test("Outline writes and reads back via OKFBundle")
    func testOKFBundleRoundTrip() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "outline-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundle = OKFBundle(root: tmp)
        let outline = Outline(
            identifier: "outline.toc",
            name: "Campaign Table of Contents",
            nodes: [OutlineNode(title: "Act I")]
        )
        try bundle.write(outline, to: "outline.md")

        let decoded = try OKFReader.decode(Outline.self, contentsOf: tmp.appending(path: "outline.md"))
        #expect(decoded.name == outline.name)
        #expect(decoded.nodes == outline.nodes)
    }
}
