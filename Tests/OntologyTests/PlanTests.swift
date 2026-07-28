import Foundation
import Testing

@testable import Ontology

@Suite
struct PlanTests {

    @Test("Basic initialization works correctly")
    func testBasicInit() {
        let plan = Plan(name: "Weekly Game Session", rrule: "FREQ=WEEKLY;BYDAY=FR")
        #expect(plan.name == "Weekly Game Session")
        #expect(plan.rrule == "FREQ=WEEKLY;BYDAY=FR")
        #expect(plan.identifier == nil)
        #expect(plan.location == nil)
    }

    @Test("Plan has correct taxon")
    func testTaxon() {
        let plan = Plan(identifier: "plan.abc12345", name: "Campaign Kickoff")
        #expect(plan.taxon == .plan)
        #expect(plan.id == "plan.abc12345")
    }

    @Test("Plan conforms to Entity")
    func testEntityConformance() {
        let plan: any Entity = Plan(name: "Test")
        #expect(plan.taxon == .plan)
        #expect(plan.whole == nil)
        #expect(plan.parts.isEmpty)
    }

    @Test("Encoding includes all set fields and no JSON-LD framing")
    func testEncoding() throws {
        let plan = Plan(
            identifier: "plan.abc12345",
            name: "Campaign Kickoff",
            description: "First session of the year",
            rrule: "FREQ=WEEKLY;BYDAY=FR",
            tags: ["campaign", "intro"]
        )
        let data = try JSONEncoder().encode(plan)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["id"] as? String == "plan.abc12345")
        #expect(json["name"] as? String == "Campaign Kickoff")
        #expect(json["rrule"] as? String == "FREQ=WEEKLY;BYDAY=FR")
        #expect((json["tags"] as? [String])?.contains("campaign") == true)

        // Framing belongs to the JSON-LD boundary, not to the hub type.
        #expect(json["@context"] == nil)
        #expect(json["@type"] == nil)
        #expect(json["@id"] == nil)
    }

    @Test("JSONLD.object frames the plan as schema.org")
    func testJSONLDEnvelope() throws {
        let plan = Plan(identifier: "plan.abc12345", name: "Campaign Kickoff")
        let json = try JSONLD.object(plan)

        #expect(json["@context"]?.string == "https://schema.org")
        #expect(json["@type"]?.string == "Plan")
        #expect(json["@id"]?.string == "plan.abc12345")
        #expect(json["id"] == nil)
        #expect(json["name"]?.string == "Campaign Kickoff")
    }

    @Test("JSON-LD round-trip preserves all fields")
    func testRoundTrip() throws {
        let original = Plan(
            identifier: "plan.abc12345",
            name: "Dragon Arc",
            description: "The main story arc",
            rrule: "FREQ=WEEKLY;BYDAY=SA",
            tags: ["arc", "dragon"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)

        #expect(decoded.identifier == original.identifier)
        #expect(decoded.name == original.name)
        #expect(decoded.description == original.description)
        #expect(decoded.rrule == original.rrule)
        #expect(decoded.tags == original.tags)
    }

    @Test("Frontmatter round-trip decodes correctly")
    func testFrontmatterDecode() throws {
        let yaml = """
        name: Weekly Game Session
        description: "Friday night game"
        rrule: "FREQ=WEEKLY;BYDAY=FR"
        """
        let plan = try FrontmatterParser.decode(Plan.self, from: yaml)
        #expect(plan.name == "Weekly Game Session")
        #expect(plan.rrule == "FREQ=WEEKLY;BYDAY=FR")
    }
}

@Suite
struct OccurrenceTests {

    @Test("Basic initialization works correctly")
    func testBasicInit() {
        let occ = Occurrence(name: "Session 1", description: "The party meets at the inn.")
        #expect(occ.name == "Session 1")
        #expect(occ.description == "The party meets at the inn.")
        #expect(occ.plan == nil)
    }

    @Test("Occurrence has correct taxon")
    func testTaxon() {
        let occ = Occurrence(identifier: "occurrence.aa12bb34")
        #expect(occ.taxon == .occurrence)
        #expect(occ.id == "occurrence.aa12bb34")
    }

    @Test("Back-reference to Plan via HolonRef")
    func testPlanRef() {
        let planRef = HolonRef.entity(.plan, "plan.abc12345")
        let occ = Occurrence(name: "Session 1", plan: planRef)
        #expect(occ.plan == planRef)
    }

    @Test("JSON-LD round-trip preserves all fields")
    func testRoundTrip() throws {
        let planRef = HolonRef.entity(.plan, "plan.abc12345")
        let place = Place(name: "The Rusty Flagon")
        let original = Occurrence(
            identifier: "occurrence.aa12bb34",
            name: "Session 1",
            description: "The party gathers.",
            place: place,
            plan: planRef
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Occurrence.self, from: data)

        #expect(decoded.identifier == original.identifier)
        #expect(decoded.name == original.name)
        #expect(decoded.plan == planRef)
        #expect(decoded.place?.name == "The Rusty Flagon")
    }
}

@Suite
struct RecordTests {

    @Test("Basic initialization works correctly")
    func testBasicInit() {
        let ref = HolonRef.entity(.occurrence, "occurrence.aa12bb34")
        let record = Record(name: "Session Notes", subject: ref, outcome: "Heroes defeated the goblin king.")
        #expect(record.name == "Session Notes")
        #expect(record.subject == ref)
        #expect(record.outcome == "Heroes defeated the goblin king.")
    }

    @Test("Record has correct taxon")
    func testTaxon() {
        let record = Record(identifier: "record.rr99ss11")
        #expect(record.taxon == .record)
        #expect(record.id == "record.rr99ss11")
    }

    @Test("JSON-LD round-trip preserves all fields")
    func testRoundTrip() throws {
        let ref = HolonRef.entity(.plan, "plan.abc12345")
        let original = Record(
            identifier: "record.rr99ss11",
            name: "Arc Summary",
            subject: ref,
            outcome: "The dragon was slain.",
            recordedAt: DateTime(Date(timeIntervalSince1970: 1_700_000_000))
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Record.self, from: data)

        #expect(decoded.identifier == original.identifier)
        #expect(decoded.name == original.name)
        #expect(decoded.subject == ref)
        #expect(decoded.outcome == original.outcome)
    }
}

@Suite
struct CollectionTests {

    @Test("Basic initialization with members")
    func testBasicInit() {
        let members: [HolonRef] = [
            .entity(.person, "person.3f8a91b2"),
            .entity(.place, "place.inn01"),
        ]
        let col = Collection(
            identifier: "collection.arc1",
            name: "The Dragon Arc",
            members: members
        )
        #expect(col.name == "The Dragon Arc")
        #expect(col.members.count == 2)
        #expect(col.taxon == .collection)
    }

    @Test("Empty members by default")
    func testDefaultMembers() {
        let col = Collection(name: "Empty Set")
        #expect(col.members.isEmpty)
    }

    @Test("JSON-LD round-trip preserves members")
    func testRoundTrip() throws {
        let original = Collection(
            identifier: "collection.arc1",
            name: "The Dragon Arc",
            members: [
                .entity(.person, "person.3f8a91b2"),
                .entity(.place, "place.inn01"),
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Collection.self, from: data)

        #expect(decoded.identifier == original.identifier)
        #expect(decoded.name == original.name)
        #expect(decoded.members == original.members)
    }
}
