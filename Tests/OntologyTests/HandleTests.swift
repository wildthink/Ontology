import Foundation
import Ontology
import OntologyGoogle
import Testing

@Suite("Handle — alternate identifiers")
struct HandleTests {

    // MARK: - Construction and collection helpers

    @Test("value(for:) returns first match")
    func testValueLookup() {
        let handles: [Handle] = [
            Handle(kind: Handle.Kind.appleContacts, value: "apple-uuid-001"),
            Handle(kind: Handle.Kind.googlePeople, value: "people/123456"),
            Handle(kind: Handle.Kind.email, value: "jane@example.com", label: "Work")
        ]

        #expect(handles.value(for: Handle.Kind.appleContacts) == "apple-uuid-001")
        #expect(handles.value(for: Handle.Kind.googlePeople) == "people/123456")
        #expect(handles.value(for: Handle.Kind.email) == "jane@example.com")
        #expect(handles.value(for: "nonexistent") == nil)
    }

    @Test("all(for:) returns every match for a kind")
    func testAllForKind() {
        let handles: [Handle] = [
            Handle(kind: Handle.Kind.email, value: "work@example.com", label: "Work"),
            Handle(kind: Handle.Kind.email, value: "home@example.com", label: "Home"),
            Handle(kind: Handle.Kind.phone, value: "+15555551234")
        ]

        #expect(handles.all(for: Handle.Kind.email).count == 2)
        #expect(handles.all(for: Handle.Kind.phone).count == 1)
        #expect(handles.all(for: Handle.Kind.googlePeople).isEmpty)
    }

    @Test("contains(kind:value:) checks exact match")
    func testContains() {
        let handles: [Handle] = [
            Handle(kind: Handle.Kind.appleContacts, value: "uuid-001")
        ]

        #expect(handles.contains(kind: Handle.Kind.appleContacts, value: "uuid-001"))
        #expect(!handles.contains(kind: Handle.Kind.appleContacts, value: "uuid-999"))
        #expect(!handles.contains(kind: Handle.Kind.googlePeople, value: "uuid-001"))
    }

    // MARK: - Codable round-trip

    @Test("Handle round-trips through JSON")
    func testHandleRoundTrip() throws {
        let original = Handle(kind: Handle.Kind.googlePeople, value: "people/987654", label: "Google")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Handle.self, from: data)

        #expect(decoded.kind == Handle.Kind.googlePeople)
        #expect(decoded.value == "people/987654")
        #expect(decoded.label == "Google")
    }

    @Test("Person with handles round-trips through JSON")
    func testPersonHandlesRoundTrip() throws {
        var person = Person(givenName: "Jane", familyName: "Smith")
        person.handles = [
            Handle(kind: Handle.Kind.appleContacts, value: "apple-uuid-abc"),
            Handle(kind: Handle.Kind.googlePeople, value: "people/123"),
            Handle(kind: Handle.Kind.email, value: "jane@example.com")
        ]

        let data = try JSONEncoder().encode(person)
        let decoded = try JSONDecoder().decode(Person.self, from: data)

        #expect(decoded.handles?.count == 3)
        #expect(decoded.handles?.value(for: Handle.Kind.appleContacts) == "apple-uuid-abc")
        #expect(decoded.handles?.value(for: Handle.Kind.googlePeople) == "people/123")
        #expect(decoded.handles?.value(for: Handle.Kind.email) == "jane@example.com")
    }

    @Test("Organization with handles round-trips through JSON")
    func testOrgHandlesRoundTrip() throws {
        let org = Organization(
            identifier: "org.001",
            name: "Moonshae Guild",
            handles: [Handle(kind: Handle.Kind.appleContacts, value: "org-apple-uuid")]
        )

        let data = try JSONEncoder().encode(org)
        let decoded = try JSONDecoder().decode(Organization.self, from: data)

        #expect(decoded.handles?.value(for: Handle.Kind.appleContacts) == "org-apple-uuid")
        #expect(decoded.name == "Moonshae Guild")
    }

    @Test("Occurrence with handles round-trips through JSON")
    func testOccurrenceHandlesRoundTrip() throws {
        let occ = Occurrence(
            name: "Session 12",
            startDate: DateTime(Date(timeIntervalSinceReferenceDate: 0), timeZone: .gmt),
            handles: [
                Handle(kind: Handle.Kind.appleCalendarItem, value: "ek-item-id"),
                Handle(kind: Handle.Kind.appleCalendarItemExt, value: "ek-ext-id"),
                Handle(kind: Handle.Kind.googleCalendar, value: "gcal-event-abc")
            ]
        )

        let data = try JSONEncoder().encode(occ)
        let decoded = try JSONDecoder().decode(Occurrence.self, from: data)

        #expect(decoded.handles?.count == 3)
        #expect(decoded.handles?.value(for: Handle.Kind.googleCalendar) == "gcal-event-abc")
        #expect(decoded.handles?.value(for: Handle.Kind.appleCalendarItem) == "ek-item-id")
    }

    @Test("Plan with handles round-trips through JSON")
    func testPlanHandlesRoundTrip() throws {
        let plan = Plan(
            name: "Campaign Arc 3",
            handles: [Handle(kind: Handle.Kind.googleCalendar, value: "gcal-recurring-master")]
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)

        #expect(decoded.handles?.value(for: Handle.Kind.googleCalendar) == "gcal-recurring-master")
    }

    @Test("Task with handles round-trips through JSON")
    func testTaskHandlesRoundTrip() throws {
        let task = Task(
            name: "Paint minis",
            handles: [Handle(kind: Handle.Kind.googleTasks, value: "gtask-abc123")]
        )

        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)

        #expect(decoded.handles?.value(for: Handle.Kind.googleTasks) == "gtask-abc123")
    }

    // MARK: - Bridge integration

    @Test("GPerson bridge populates googlePeople handle on Person")
    func testGPersonBridgeHandle() throws {
        let json = """
        {
          "resourceName": "people/c123456",
          "names": [{"givenName": "Jane", "familyName": "Smith"}],
          "emailAddresses": [{"value": "jane@example.com"}]
        }
        """
        let g = try JSONDecoder().decode(GPerson.self, from: Data(json.utf8))
        let person = Person(g)

        #expect(person.handles?.value(for: Handle.Kind.googlePeople) == "people/c123456")
        // email stays separate — not promoted to a handle automatically
        #expect(person.email == ["jane@example.com"])
        #expect(person.handles?.value(for: Handle.Kind.email) == nil)
    }

    @Test("GPerson write direction prefers googlePeople handle over identifier")
    func testGPersonWriteUsesHandle() {
        var person = Person(givenName: "Jane", familyName: "Smith")
        person.identifier = "person.canonical-hub-id"
        person.handles = [Handle(kind: Handle.Kind.googlePeople, value: "people/c123456")]

        let g = GPerson(person)
        #expect(g.resourceName == "people/c123456")
    }

    @Test("GCalEvent bridge populates googleCalendar handle on Occurrence")
    func testGCalEventBridgeHandle() throws {
        let json = """
        {
          "id": "gcal-evt-001",
          "summary": "Session 12",
          "start": {"dateTime": "2024-06-15T19:00:00Z"},
          "end":   {"dateTime": "2024-06-15T22:00:00Z"}
        }
        """
        let gcal = try JSONDecoder().decode(GCalEvent.self, from: Data(json.utf8))
        let occ = Occurrence(gcal)

        #expect(occ.handles?.value(for: Handle.Kind.googleCalendar) == "gcal-evt-001")
    }

    @Test("GCalEvent write direction prefers googleCalendar handle over identifier")
    func testGCalWriteUsesHandle() {
        var occ = Occurrence(name: "Session 12")
        occ.identifier = "occurrence.canonical"
        occ.handles = [Handle(kind: Handle.Kind.googleCalendar, value: "gcal-evt-001")]

        let gcal = GCalEvent(occ)
        #expect(gcal.id == "gcal-evt-001")
    }

    @Test("GTask bridge populates googleTasks handle on Task")
    func testGTaskBridgeHandle() throws {
        let json = """
        { "id": "task-xyz", "title": "Buy supplies", "status": "needsAction" }
        """
        let g = try JSONDecoder().decode(GTask.self, from: Data(json.utf8))
        let task = Task(g)

        #expect(task.handles?.value(for: Handle.Kind.googleTasks) == "task-xyz")
    }

    @Test("GTask write direction prefers googleTasks handle over identifier")
    func testGTaskWriteUsesHandle() {
        var task = Task(name: "Buy supplies")
        task.identifier = "task.canonical"
        task.handles = [Handle(kind: Handle.Kind.googleTasks, value: "task-xyz")]

        let g = GTask(task)
        #expect(g.id == "task-xyz")
    }

    // MARK: - Proxy identifier pattern

    @Test("Email handle enables lookup without a canonical identifier")
    func testEmailProxyIdentifier() {
        var person = Person(givenName: "Unknown", familyName: "Player")
        // No canonical identifier set yet — using email as proxy
        person.handles = [Handle(kind: Handle.Kind.email, value: "player@example.com")]

        #expect(person.identifier == nil)
        #expect(person.handles?.value(for: Handle.Kind.email) == "player@example.com")
    }

    @Test("Multiple system handles coexist on one Person")
    func testMultiSystemHandles() {
        var person = Person(givenName: "Jane", familyName: "GM")
        person.identifier = "person.abc123"
        person.handles = [
            Handle(kind: Handle.Kind.appleContacts, value: "cn-uuid-001", label: "Apple"),
            Handle(kind: Handle.Kind.googlePeople, value: "people/c456", label: "Google"),
            Handle(kind: Handle.Kind.email, value: "gm@example.com")
        ]

        // All three systems can independently look up this Person
        #expect(person.handles?.value(for: Handle.Kind.appleContacts) != nil)
        #expect(person.handles?.value(for: Handle.Kind.googlePeople) != nil)
        #expect(person.handles?.value(for: Handle.Kind.email) != nil)
        // Canonical hub ID is independent
        #expect(person.identifier == "person.abc123")
    }
}
