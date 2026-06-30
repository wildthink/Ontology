import Foundation
import Ontology
import OntologyGoogle
import Testing

@Suite("Alarm value type")
struct AlarmTests {

    // MARK: - Construction conveniences

    @Test("minutesBefore produces negative offsetMinutes")
    func testMinutesBefore() {
        let a = Alarm.minutesBefore(15)
        guard case .offsetMinutes(let n) = a.trigger else {
            Issue.record("Expected offsetMinutes trigger")
            return
        }
        #expect(n == -15)
        #expect(a.method == "display")
    }

    @Test("at(_:) produces absoluteDate trigger")
    func testAt() {
        let dt = DateTime(Date(timeIntervalSinceReferenceDate: 0))
        let a = Alarm.at(dt, method: "email")
        guard case .absoluteDate(let got) = a.trigger else {
            Issue.record("Expected absoluteDate trigger")
            return
        }
        #expect(got.value == dt.value)
        #expect(a.method == "email")
    }

    // MARK: - Codable round-trip

    @Test("offsetMinutes alarm round-trips through JSON")
    func testOffsetRoundTrip() throws {
        let alarm = Alarm.minutesBefore(30, method: "email")
        let data = try JSONEncoder().encode(alarm)
        let decoded = try JSONDecoder().decode(Alarm.self, from: data)

        guard case .offsetMinutes(let n) = decoded.trigger else {
            Issue.record("Expected offsetMinutes")
            return
        }
        #expect(n == -30)
        #expect(decoded.method == "email")
    }

    @Test("absoluteDate alarm round-trips through JSON")
    func testAbsoluteDateRoundTrip() throws {
        let dt = DateTime(Date(timeIntervalSinceReferenceDate: 86400), timeZone: .gmt)
        let alarm = Alarm.at(dt)
        let data = try JSONEncoder().encode(alarm)
        let decoded = try JSONDecoder().decode(Alarm.self, from: data)

        guard case .absoluteDate(let got) = decoded.trigger else {
            Issue.record("Expected absoluteDate")
            return
        }
        #expect(abs(got.value.timeIntervalSince(dt.value)) < 1)
    }

    @Test("Plan with alarms round-trips through JSON")
    func testPlanAlarmRoundTrip() throws {
        let plan = Plan(
            name: "Session prep",
            alarms: [
                .minutesBefore(60),
                .minutesBefore(15, method: "email")
            ]
        )
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)

        #expect(decoded.alarms?.count == 2)
        if case .offsetMinutes(let n) = decoded.alarms?.first?.trigger {
            #expect(n == -60)
        }
    }

    @Test("Occurrence with alarms round-trips through JSON")
    func testOccurrenceAlarmRoundTrip() throws {
        let occ = Occurrence(
            name: "Game session",
            startDate: DateTime(Date(timeIntervalSinceReferenceDate: 0)),
            alarms: [.minutesBefore(30)]
        )
        let data = try JSONEncoder().encode(occ)
        let decoded = try JSONDecoder().decode(Occurrence.self, from: data)

        #expect(decoded.alarms?.count == 1)
    }

    @Test("Task with alarms round-trips through JSON")
    func testTaskAlarmRoundTrip() throws {
        let task = Task(
            name: "Print character sheets",
            alarms: [.minutesBefore(120)]
        )
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)

        #expect(decoded.alarms?.count == 1)
        if case .offsetMinutes(let n) = decoded.alarms?.first?.trigger {
            #expect(n == -120)
        }
    }

    // MARK: - Google Calendar reminder bridge

    @Test("Alarm converts to GCalEvent.Reminders.Override and back")
    func testGCalReminderBridge() {
        let alarm = Alarm.minutesBefore(10, method: "display")
        let override = GCalEvent.Reminders.Override(alarm)

        #expect(override.method == "popup")
        #expect(override.minutes == 10)

        let decoded = Alarm(googleReminder: override)
        guard case .offsetMinutes(let n) = decoded.trigger else {
            Issue.record("Expected offsetMinutes")
            return
        }
        #expect(n == -10)
        #expect(decoded.method == "display")
    }

    @Test("GCalEvent with reminders maps alarms into Occurrence")
    func testGCalEventRemindersToOccurrence() throws {
        let json = """
        {
          "id": "evt001",
          "summary": "Session 12",
          "start": { "dateTime": "2024-06-15T19:00:00Z" },
          "end":   { "dateTime": "2024-06-15T22:00:00Z" },
          "reminders": {
            "useDefault": false,
            "overrides": [
              { "method": "popup", "minutes": 30 },
              { "method": "email", "minutes": 1440 }
            ]
          }
        }
        """
        let gcal = try JSONDecoder().decode(GCalEvent.self, from: Data(json.utf8))
        let occ = Occurrence(gcal)

        #expect(occ.alarms?.count == 2)
        if case .offsetMinutes(let n) = occ.alarms?.first?.trigger {
            #expect(n == -30)
        }
        #expect(occ.alarms?.first?.method == "display")
        #expect(occ.alarms?.last?.method == "email")
    }

    @Test("Occurrence alarms round-trip through GCalEvent")
    func testOccurrenceAlarmsRoundTripGCal() {
        let occ = Occurrence(
            name: "Battle of the Moonshae",
            startDate: DateTime(Date(timeIntervalSinceReferenceDate: 0), timeZone: .gmt),
            alarms: [.minutesBefore(15), .minutesBefore(60, method: "email")]
        )
        let gcal = GCalEvent(occ)

        #expect(gcal.reminders?.useDefault == false)
        #expect(gcal.reminders?.overrides?.count == 2)
        #expect(gcal.reminders?.overrides?.first?.minutes == 15)
        #expect(gcal.reminders?.overrides?.last?.method == "email")

        let roundTripped = Occurrence(gcal)
        #expect(roundTripped.alarms?.count == 2)
    }
}
