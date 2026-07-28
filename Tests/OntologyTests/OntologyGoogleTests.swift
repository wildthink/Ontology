import Foundation
import Ontology
import OntologyGoogle
import Testing

@Suite("OntologyGoogle — JSON bridge")
struct OntologyGoogleTests {

    // MARK: - GCalEvent → Occurrence

    @Test("GCalEvent maps to Occurrence fields")
    func testCalEventToOccurrence() throws {
        let json = """
        {
          "id": "evt001",
          "summary": "Tavern Meeting",
          "description": "Planning session at The Rusty Flagon",
          "location": "The Rusty Flagon, Market District",
          "status": "confirmed",
          "htmlLink": "https://calendar.google.com/event?id=evt001",
          "start": { "dateTime": "2024-06-15T19:00:00-07:00", "timeZone": "America/Los_Angeles" },
          "end":   { "dateTime": "2024-06-15T21:00:00-07:00", "timeZone": "America/Los_Angeles" },
          "organizer": { "email": "gm@campaign.net", "displayName": "Game Master" },
          "attendees": [
            { "email": "player1@example.com", "displayName": "Alice", "responseStatus": "accepted" },
            { "email": "player2@example.com", "displayName": "Bob",   "responseStatus": "tentative" }
          ]
        }
        """
        let gcal = try JSONDecoder().decode(GCalEvent.self, from: Data(json.utf8))
        let occ = Occurrence(gcal)

        #expect(occ.identifier == "evt001")
        #expect(occ.name == "Tavern Meeting")
        #expect(occ.description == "Planning session at The Rusty Flagon")
        #expect(occ.location == "The Rusty Flagon, Market District")
        #expect(occ.status == "EventScheduled")
        #expect(occ.url?.absoluteString == "https://calendar.google.com/event?id=evt001")
        #expect(occ.organizer?.email?.first == "gm@campaign.net")
        #expect(occ.attendees?.count == 2)
        #expect(occ.attendees?.first?.email?.first == "player1@example.com")
        #expect(occ.plan == nil)

        let tz = occ.startDate?.timeZone
        #expect(tz?.secondsFromGMT() == -7 * 3600)
    }

    @Test("GCalEvent instance links back to recurring Plan")
    func testCalEventInstanceLinksPlan() throws {
        let json = """
        {
          "id": "instance_001",
          "summary": "Weekly Stand-up",
          "recurringEventId": "master_xyz",
          "start": { "dateTime": "2024-06-17T09:00:00Z" },
          "end":   { "dateTime": "2024-06-17T09:30:00Z" }
        }
        """
        let gcal = try JSONDecoder().decode(GCalEvent.self, from: Data(json.utf8))
        let occ = Occurrence(gcal)

        #expect(occ.plan == .entity(.plan, "master_xyz"))
    }

    @Test("GCalEvent recurring master maps to Plan with rrule")
    func testCalEventMasterToPlan() throws {
        let json = """
        {
          "id": "master_xyz",
          "summary": "Weekly Stand-up",
          "recurrence": ["RRULE:FREQ=WEEKLY;BYDAY=MO", "EXDATE;TZID=UTC:20240101T090000Z"],
          "start": { "dateTime": "2024-06-17T09:00:00Z" },
          "end":   { "dateTime": "2024-06-17T09:30:00Z" }
        }
        """
        let gcal = try JSONDecoder().decode(GCalEvent.self, from: Data(json.utf8))
        let plan = Plan(gcal)

        #expect(plan.identifier == "master_xyz")
        #expect(plan.name == "Weekly Stand-up")
        #expect(plan.rrule == "FREQ=WEEKLY;BYDAY=MO")
        // EXDATE rides on its own line in Google's recurrence array; it used to be
        // dropped on the floor here.
        #expect(plan.exceptDates?.count == 1)
    }

    @Test("GCalEvent all-day (date-only) parses without crash")
    func testCalEventAllDay() throws {
        let json = """
        {
          "id": "allday001",
          "summary": "Festival Day",
          "start": { "date": "2024-07-04" },
          "end":   { "date": "2024-07-05" }
        }
        """
        let gcal = try JSONDecoder().decode(GCalEvent.self, from: Data(json.utf8))
        let occ = Occurrence(gcal)

        #expect(occ.name == "Festival Day")
        #expect(occ.startDate != nil)
    }

    @Test("GCalEventList wraps items array")
    func testCalEventList() throws {
        let json = """
        { "items": [
            { "id": "a", "summary": "First",  "start": {"dateTime":"2024-01-01T10:00:00Z"}, "end": {"dateTime":"2024-01-01T11:00:00Z"} },
            { "id": "b", "summary": "Second", "start": {"dateTime":"2024-01-02T10:00:00Z"}, "end": {"dateTime":"2024-01-02T11:00:00Z"} }
          ]
        }
        """
        let list = try JSONDecoder().decode(GCalEventList.self, from: Data(json.utf8))
        let occurrences = (list.items ?? []).map { Occurrence($0) }

        #expect(occurrences.count == 2)
        #expect(occurrences[0].name == "First")
        #expect(occurrences[1].name == "Second")
    }

    // MARK: - GCalCalendar → Collection

    @Test("GCalCalendar maps to Collection")
    func testCalCalendarToCollection() throws {
        let json = """
        {
          "id": "cal_main@group.calendar.google.com",
          "summary": "Campaign Events",
          "description": "All events for the Moonshae campaign",
          "primary": true
        }
        """
        let gcal = try JSONDecoder().decode(GCalCalendar.self, from: Data(json.utf8))
        let col = Collection(gcal)

        #expect(col.identifier == "cal_main@group.calendar.google.com")
        #expect(col.name == "Campaign Events")
        #expect(col.description == "All events for the Moonshae campaign")
    }

    // MARK: - GPerson → Person

    @Test("GPerson maps givenName, familyName, email, telephone")
    func testGPersonToPerson() throws {
        let json = """
        {
          "resourceName": "people/c42",
          "names": [{ "givenName": "Jane", "familyName": "Smith", "displayName": "Jane Smith" }],
          "emailAddresses": [{ "value": "jane@example.com", "type": "work" }],
          "phoneNumbers": [{ "value": "+1-555-0100", "type": "mobile" }],
          "organizations": [{ "name": "Acme Corp", "title": "Senior Engineer" }]
        }
        """
        let g = try JSONDecoder().decode(GPerson.self, from: Data(json.utf8))
        let person = Person(g)

        #expect(person.identifier == "people/c42")
        #expect(person.givenName == "Jane")
        #expect(person.familyName == "Smith")
        #expect(person.email?.first == "jane@example.com")
        #expect(person.telephone?.first == "+1-555-0100")
        #expect(person.jobTitle == "Senior Engineer")
        #expect(person.worksFor?.name == "Acme Corp")
    }

    // MARK: - GTask → Plan

    @Test("GTask maps to Plan with due date")
    func testGTaskToPlan() throws {
        let json = """
        {
          "id": "task_abc",
          "title": "Prep battle map",
          "notes": "Draw the goblin lair for session 12",
          "status": "needsAction",
          "due": "2024-06-20T00:00:00.000Z",
          "selfLink": "https://tasks.googleapis.com/tasks/v1/lists/default/tasks/task_abc"
        }
        """
        let g = try JSONDecoder().decode(GTask.self, from: Data(json.utf8))
        let plan = Plan(g)

        #expect(plan.identifier == "task_abc")
        #expect(plan.name == "Prep battle map")
        #expect(plan.description == "Draw the goblin lair for session 12")
        #expect(plan.startDate != nil)
        #expect(plan.url?.absoluteString.contains("task_abc") == true)
    }

    // MARK: - GDriveFile → Record

    @Test("GDriveFile maps to Record with url and recordedAt")
    func testGDriveFileToRecord() throws {
        let json = """
        {
          "id": "file_xyz",
          "name": "Session 12 Notes",
          "description": "Combat and story outcomes from session 12",
          "mimeType": "application/vnd.google-apps.document",
          "modifiedTime": "2024-06-16T22:00:00Z",
          "webViewLink": "https://docs.google.com/document/d/file_xyz/edit"
        }
        """
        let g = try JSONDecoder().decode(GDriveFile.self, from: Data(json.utf8))
        let record = Record(g)

        #expect(record.identifier == "file_xyz")
        #expect(record.name == "Session 12 Notes")
        #expect(record.description == "Combat and story outcomes from session 12")
        #expect(record.url?.absoluteString == "https://docs.google.com/document/d/file_xyz/edit")
        #expect(record.recordedAt != nil)
    }

    // MARK: - Occurrence → GCalEvent (write direction)

    @Test("Occurrence round-trips through GCalEvent")
    func testOccurrenceToGCalEvent() throws {
        let occ = Occurrence(
            identifier: "evt001",
            name: "Tavern Meeting",
            description: "Planning session",
            startDate: DateTime(Date(timeIntervalSinceReferenceDate: 0), timeZone: .gmt),
            endDate: DateTime(Date(timeIntervalSinceReferenceDate: 3600), timeZone: .gmt),
            location: "The Rusty Flagon",
            url: URL(string: "https://example.com"),
            status: "EventScheduled"
        )
        let gcal = GCalEvent(occ)

        #expect(gcal.id == "evt001")
        #expect(gcal.summary == "Tavern Meeting")
        #expect(gcal.description == "Planning session")
        #expect(gcal.location == "The Rusty Flagon")
        #expect(gcal.status == "confirmed")
        #expect(gcal.start?.dateTime != nil)

        let roundTripped = Occurrence(gcal)
        #expect(roundTripped.identifier == occ.identifier)
        #expect(roundTripped.name == occ.name)
        #expect(roundTripped.status == occ.status)
    }

    @Test("Plan round-trips through GCalEvent")
    func testPlanToGCalEvent() throws {
        let plan = Plan(
            identifier: "master_xyz",
            name: "Weekly Stand-up",
            startDate: DateTime(Date(timeIntervalSinceReferenceDate: 0), timeZone: .gmt),
            rrule: "FREQ=WEEKLY;BYDAY=MO"
        )
        let gcal = GCalEvent(plan)

        #expect(gcal.id == "master_xyz")
        #expect(gcal.summary == "Weekly Stand-up")
        #expect(gcal.recurrence == ["RRULE:FREQ=WEEKLY;BYDAY=MO"])

        let roundTripped = Plan(gcal)
        #expect(roundTripped.identifier == plan.identifier)
        #expect(roundTripped.name == plan.name)
        #expect(roundTripped.rrule == plan.rrule)
    }

    @Test("Plan exceptDates round-trip through GCalEvent as an EXDATE line")
    func testPlanExceptDatesToGCalEvent() throws {
        let cancelled = try #require(DateTime(string: "2026-01-05T09:00:00Z"))
        let plan = Plan(
            identifier: "master_xyz",
            name: "Weekly Stand-up",
            startDate: DateTime(Date(timeIntervalSinceReferenceDate: 0), timeZone: .gmt),
            rrule: "FREQ=WEEKLY;BYDAY=MO",
            exceptDates: [cancelled]
        )
        let gcal = GCalEvent(plan)

        #expect(gcal.recurrence?.count == 2)
        #expect(gcal.recurrence?.contains("RRULE:FREQ=WEEKLY;BYDAY=MO") == true)
        #expect(gcal.recurrence?.contains("EXDATE:20260105T090000Z") == true)

        let roundTripped = Plan(gcal)
        #expect(roundTripped.rrule == plan.rrule)
        #expect(roundTripped.exceptDates?.count == 1)
        #expect(roundTripped.exceptDates?.first?.value == cancelled.value)
    }

    @Test("A plan with neither rule nor exceptions writes no recurrence array")
    func testPlanWithoutRecurrence() {
        let gcal = GCalEvent(Plan(identifier: "x", name: "One-off"))
        #expect(gcal.recurrence == nil)
    }

    @Test("GCalEvent encodes to JSON (write path)")
    func testGCalEventEncodes() throws {
        let occ = Occurrence(
            name: "Session Zero",
            startDate: DateTime(Date(timeIntervalSinceReferenceDate: 0), timeZone: .gmt)
        )
        let gcal = GCalEvent(occ)
        let data = try JSONEncoder().encode(gcal)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["summary"] as? String == "Session Zero")
        #expect((json["start"] as? [String: Any])?["dateTime"] as? String != nil)
    }

    // MARK: - GPerson → Person round-trip

    @Test("Person round-trips through GPerson")
    func testPersonToGPersonRoundTrip() throws {
        let person = Person(
            identifier: "people/c42",
            givenName: "Jane",
            familyName: "Smith",
            email: ["jane@example.com"],
            telephone: ["+1-555-0100"],
            jobTitle: "Senior Engineer",
            worksFor: Organization(name: "Acme Corp")
        )
        let g = GPerson(person)

        #expect(g.resourceName == "people/c42")
        #expect(g.names?.first?.givenName == "Jane")
        #expect(g.names?.first?.familyName == "Smith")
        #expect(g.emailAddresses?.first?.value == "jane@example.com")
        #expect(g.phoneNumbers?.first?.value == "+1-555-0100")
        #expect(g.organizations?.first?.title == "Senior Engineer")
        #expect(g.organizations?.first?.name == "Acme Corp")

        let roundTripped = Person(g)
        #expect(roundTripped.givenName == person.givenName)
        #expect(roundTripped.familyName == person.familyName)
        #expect(roundTripped.email?.first == person.email?.first)
    }

    // MARK: - Plan → GTask round-trip

    @Test("Plan round-trips through GTask")
    func testPlanToGTaskRoundTrip() throws {
        let plan = Plan(
            identifier: "task_abc",
            name: "Prep battle map",
            description: "Draw the goblin lair",
            startDate: DateTime(Date(timeIntervalSinceReferenceDate: 86400), timeZone: .gmt)
        )
        let g = GTask(plan)

        #expect(g.id == "task_abc")
        #expect(g.title == "Prep battle map")
        #expect(g.notes == "Draw the goblin lair")
        #expect(g.due != nil)

        let roundTripped = Plan(g)
        #expect(roundTripped.identifier == plan.identifier)
        #expect(roundTripped.name == plan.name)
        #expect(roundTripped.description == plan.description)
    }

    // MARK: - Occurrence.normalizedStatus

    @Test("normalizedStatus maps Google and Schema.org vocabulary")
    func testNormalizedStatus() {
        #expect(Occurrence.normalizedStatus("confirmed") == "EventScheduled")
        #expect(Occurrence.normalizedStatus("tentative") == "tentative")  // no Schema.org equivalent; pass through
        #expect(Occurrence.normalizedStatus("cancelled") == "EventCancelled")
        #expect(Occurrence.normalizedStatus("EventScheduled") == "EventScheduled")
        #expect(Occurrence.normalizedStatus(nil) == nil)
        #expect(Occurrence.normalizedStatus("") == nil)
        #expect(Occurrence.normalizedStatus("custom") == "custom")
    }
}
