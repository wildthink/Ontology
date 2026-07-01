import Foundation
import Testing

@testable import Ontology
import OntologyOKF

@Suite
struct OKFDocumentTests {

    @Test("OKF required field: type is present and matches entity kind")
    func testTypeField() throws {
        let place = Place(identifier: "place.inn01", name: "The Rusty Flagon")
        let doc = try OKFDocument(place)
        let text = doc.string()
        #expect(text.contains("type: Place"))
        #expect(!text.contains("@type"))
        #expect(!text.contains("@context"))
    }

    @Test("OKF recommended field: title mapped from name")
    func testTitleFromName() throws {
        let plan = Plan(identifier: "plan.abc", name: "Dragon Arc", description: "Main story arc")
        let doc = try OKFDocument(plan)
        let text = doc.string()
        #expect(text.contains("title: Dragon Arc"))
        #expect(text.contains("description: Main story arc"))
    }

    @Test("OKF recommended field: title derived from Person givenName + familyName")
    func testPersonTitle() throws {
        let person = Person(identifier: "person.3f8a91b2", givenName: "Jane", familyName: "Smith")
        let doc = try OKFDocument(person)
        let text = doc.string()
        #expect(text.contains("type: Person"))
        #expect(text.contains("title: Jane Smith"))
    }

    @Test("OKF recommended field: resource mapped from url")
    func testResourceFromURL() throws {
        let plan = Plan(
            identifier: "plan.abc",
            name: "Campaign",
            url: URL(string: "https://example.com/campaign")
        )
        let doc = try OKFDocument(plan)
        let text = doc.string()
        #expect(text.contains("resource:"))
        #expect(text.contains("example.com/campaign"))
    }

    @Test("OKF recommended field: timestamp from startDate")
    func testTimestampFromStartDate() throws {
        let occ = Occurrence(
            name: "Session 1",
            startDate: DateTime(Date(timeIntervalSince1970: 1_700_000_000))
        )
        let doc = try OKFDocument(occ)
        let text = doc.string()
        #expect(text.contains("timestamp:"))
    }

    @Test("OKF recommended field: timestamp from Task.dueDate")
    func testTimestampFromDueDate() throws {
        let task = Task(
            name: "Draft encounter table",
            dueDate: DateTime(Date(timeIntervalSince1970: 1_700_000_000))
        )
        let doc = try OKFDocument(task)
        let text = doc.string()
        #expect(text.contains("timestamp:"))
    }

    @Test("OKF id field preserved as extension key")
    func testIDPreserved() throws {
        let place = Place(identifier: "place.inn01", name: "The Rusty Flagon")
        let doc = try OKFDocument(place)
        let text = doc.string()
        #expect(text.contains("id: place.inn01"))
        #expect(!text.contains("@id"))
    }

    @Test("OKF key priority: type and title appear before extension fields")
    func testKeyOrdering() throws {
        let plan = Plan(identifier: "plan.abc", name: "Dragon Arc", rrule: "FREQ=WEEKLY")
        let doc = try OKFDocument(plan)
        let text = doc.string()
        let typeIdx = text.range(of: "type:")?.lowerBound
        let titleIdx = text.range(of: "title:")?.lowerBound
        let rruleIdx = text.range(of: "rrule:")?.lowerBound
        #expect(typeIdx != nil && titleIdx != nil && rruleIdx != nil)
        #expect(typeIdx! < rruleIdx!)
        #expect(titleIdx! < rruleIdx!)
    }

    @Test("OKF tags field passes through unchanged")
    func testTagsPassThrough() throws {
        let plan = Plan(name: "Arc", tags: ["campaign", "weekly"])
        let doc = try OKFDocument(plan)
        let text = doc.string()
        #expect(text.contains("tags:"))
        #expect(text.contains("campaign"))
        #expect(text.contains("weekly"))
    }

    @Test("OKF string() produces valid fenced structure")
    func testFenceStructure() throws {
        let place = Place(name: "Evermore")
        let doc = try OKFDocument(place, body: "A city of wonder.")
        let text = doc.string()
        #expect(text.hasPrefix("---\n"))
        #expect(text.contains("\n---\n"))
        #expect(text.hasSuffix("A city of wonder."))
        #expect(text.filter { $0 == "-" }.count >= 6) // at least two --- fences
    }
}

@Suite
struct OKFReaderTests {

    @Test("Round-trip Place through OKF encode → decode")
    func testPlaceRoundTrip() throws {
        let original = Place(
            identifier: "place.inn01",
            name: "The Rusty Flagon",
            description: "A well-known inn"
        )
        let doc = try OKFDocument(original)
        let recovered = try OKFReader.decode(Place.self, from: doc.string())
        #expect(recovered.identifier == original.identifier)
        #expect(recovered.name == original.name)
        #expect(recovered.description == original.description)
    }

    @Test("Round-trip Plan through OKF encode → decode")
    func testPlanRoundTrip() throws {
        let original = Plan(
            identifier: "plan.abc",
            name: "Dragon Arc",
            description: "Main story arc",
            rrule: "FREQ=WEEKLY;BYDAY=SA",
            tags: ["arc", "weekly"]
        )
        let doc = try OKFDocument(original)
        let recovered = try OKFReader.decode(Plan.self, from: doc.string())
        #expect(recovered.identifier == original.identifier)
        #expect(recovered.name == original.name)
        #expect(recovered.rrule == original.rrule)
        #expect(recovered.tags == original.tags)
    }

    @Test("Round-trip Occurrence through OKF encode → decode")
    func testOccurrenceRoundTrip() throws {
        let original = Occurrence(
            identifier: "occurrence.s01",
            name: "Session 1",
            location: "The Rusty Flagon",
            status: "EventScheduled"
        )
        let doc = try OKFDocument(original)
        let recovered = try OKFReader.decode(Occurrence.self, from: doc.string())
        #expect(recovered.identifier == original.identifier)
        #expect(recovered.name == original.name)
        #expect(recovered.location == original.location)
        #expect(recovered.status == original.status)
    }

    @Test("OKFReader maps title → name when name absent")
    func testTitleToName() throws {
        let okfFrontmatter = """
        type: Place
        title: Evermore City
        description: A magical city
        id: place.ev01
        """
        let doc = "---\n\(okfFrontmatter)\n---"
        let place = try OKFReader.decode(Place.self, from: doc)
        #expect(place.name == "Evermore City")
        #expect(place.description == "A magical city")
        #expect(place.identifier == "place.ev01")
    }

    @Test("OKFReader maps resource → url when url absent")
    func testResourceToURL() throws {
        let okfFrontmatter = """
        type: Plan
        title: My Plan
        resource: "https://example.com/plan"
        id: plan.p01
        """
        let doc = "---\n\(okfFrontmatter)\n---"
        let plan = try OKFReader.decode(Plan.self, from: doc)
        #expect(plan.url?.absoluteString == "https://example.com/plan")
    }

    @Test("OKFReader favors a hand-edited title over a stale name extension key")
    func testTitleWinsOverStaleName() throws {
        let okfFrontmatter = """
        type: Place
        title: Evermore City
        name: Old Evermore
        id: place.ev01
        """
        let doc = "---\n\(okfFrontmatter)\n---"
        let place = try OKFReader.decode(Place.self, from: doc)
        #expect(place.name == "Evermore City")
    }

    @Test("OKFReader favors a hand-edited resource over a stale url extension key")
    func testResourceWinsOverStaleURL() throws {
        let okfFrontmatter = """
        type: Plan
        title: My Plan
        resource: "https://example.com/new"
        url: "https://example.com/old"
        id: plan.p01
        """
        let doc = "---\n\(okfFrontmatter)\n---"
        let plan = try OKFReader.decode(Plan.self, from: doc)
        #expect(plan.url?.absoluteString == "https://example.com/new")
    }

    @Test("OKFReader favors a hand-edited timestamp over the stale date field it was derived from")
    func testTimestampWinsOverStaleDateField() throws {
        let okfFrontmatter = """
        type: Occurrence
        title: Session 1
        startDate: "2023-11-14T22:13:20.000Z"
        timestamp: "2024-01-01T00:00:00.000Z"
        id: occurrence.s01
        """
        let doc = "---\n\(okfFrontmatter)\n---"
        let occ = try OKFReader.decode(Occurrence.self, from: doc)
        #expect(occ.startDate?.value == DateTime(string: "2024-01-01T00:00:00.000Z")?.value)
    }

    @Test("OKFReader tolerates unknown OKF extension fields")
    func testUnknownFieldsTolerated() throws {
        let okfFrontmatter = """
        type: Place
        title: Evermore
        custom_field: some_value
        another_extension: 42
        id: place.ev01
        """
        let doc = "---\n\(okfFrontmatter)\n---"
        let place = try OKFReader.decode(Place.self, from: doc)
        #expect(place.name == "Evermore")
    }
}

@Suite
struct OKFBundleTests {

    @Test("OKFBundle write and read back a concept file")
    func testWriteAndRead() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "okf-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundle = OKFBundle(root: tmp)
        let place = Place(identifier: "place.inn01", name: "The Rusty Flagon")

        try bundle.write(place, to: "places/inn.md", body: "A cozy inn.")

        let url = tmp.appending(path: "places/inn.md")
        let recovered = try OKFReader.decode(Place.self, contentsOf: url)
        #expect(recovered.name == "The Rusty Flagon")
        #expect(recovered.identifier == "place.inn01")
    }

    @Test("OKFBundle conceptURLs excludes reserved files")
    func testConceptURLsExcludesReserved() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "okf-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundle = OKFBundle(root: tmp)
        try bundle.write(Place(name: "Inn"), to: "inn.md")
        try bundle.write(Place(name: "Market"), to: "market.md")

        // Write reserved files
        try "# Index".write(to: tmp.appending(path: "index.md"), atomically: true, encoding: .utf8)
        try "# Log".write(to: tmp.appending(path: "log.md"), atomically: true, encoding: .utf8)

        let urls = try bundle.conceptURLs()
        let names = urls.map { $0.lastPathComponent }
        #expect(names.contains("inn.md"))
        #expect(names.contains("market.md"))
        #expect(!names.contains("index.md"))
        #expect(!names.contains("log.md"))
    }

    @Test("OKFBundle conceptID strips root and .md extension")
    func testConceptID() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "okf-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundle = OKFBundle(root: tmp)
        try bundle.write(Place(name: "Inn"), to: "places/inn.md")

        let urls = try bundle.conceptURLs()
        let id = bundle.conceptID(for: urls[0])
        #expect(id == "places/inn")
    }

    @Test("OKFBundle writeIndex and readIndex round-trip")
    func testIndexRoundTrip() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "okf-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundle = OKFBundle(root: tmp)
        let col = Collection(
            identifier: "collection.arc1",
            name: "Dragon Arc",
            members: [.entity(.person, "person.3f8a91b2"), .entity(.place, "place.inn01")]
        )
        try bundle.writeIndex(col, body: "First arc of the campaign.")
        let recovered = try bundle.readIndex()
        #expect(recovered?.name == col.name)
        #expect(recovered?.identifier == col.identifier)
        #expect(recovered?.members.count == 2)
    }
}
