import Foundation
import Testing
import Universal

@testable import Ontology

@Suite("Schedule — schema.org recurrence")
struct ScheduleTests {

    // MARK: repeatFrequency parsing

    @Test("ISO 8601 duration frequencies parse to frequency + interval")
    func testISODurationFrequencies() {
        #expect(Schedule.parseFrequency("P1W")?.0 == .weekly)
        #expect(Schedule.parseFrequency("P1W")?.1 == 1)
        #expect(Schedule.parseFrequency("P2W")?.1 == 2)
        #expect(Schedule.parseFrequency("P3D")?.0 == .daily)
        #expect(Schedule.parseFrequency("P1M")?.0 == .monthly)
        #expect(Schedule.parseFrequency("P1Y")?.0 == .yearly)
        #expect(Schedule.parseFrequency("PT1H")?.0 == .hourly)
        #expect(Schedule.parseFrequency("PT30M")?.0 == .minutely)
        #expect(Schedule.parseFrequency("PT30M")?.1 == 30)
    }

    @Test("Bare word frequencies parse — schema.org's own examples use them")
    func testWordFrequencies() {
        #expect(Schedule.parseFrequency("weekly")?.0 == .weekly)
        #expect(Schedule.parseFrequency("Daily")?.0 == .daily)
        #expect(Schedule.parseFrequency("MONTHLY")?.0 == .monthly)
        #expect(Schedule.parseFrequency("annually")?.0 == .yearly)
    }

    @Test("Unparseable frequencies return nil rather than guessing")
    func testBadFrequencies() {
        #expect(Schedule.parseFrequency(nil) == nil)
        #expect(Schedule.parseFrequency("") == nil)
        #expect(Schedule.parseFrequency("fortnightly") == nil)
        #expect(Schedule.parseFrequency("P0W") == nil)
        #expect(Schedule.parseFrequency("PX") == nil)
    }

    // MARK: byDay parsing

    @Test("byDay accepts RFC 5545 tokens including signed ordinals")
    func testWeekdayTokens() {
        #expect(Schedule.parseWeekday("MO") == .every(.monday))
        #expect(Schedule.parseWeekday("fr") == .every(.friday))
        #expect(Schedule.parseWeekday("2FR") == .nth(2, .friday))
        #expect(Schedule.parseWeekday("-1SU") == .nth(-1, .sunday))
        #expect(Schedule.parseWeekday("XX") == nil)
    }

    @Test("byDay accepts schema.org DayOfWeek URLs and bare names")
    func testWeekdayURLs() {
        #expect(Schedule.parseWeekday("https://schema.org/Monday") == .every(.monday))
        #expect(Schedule.parseWeekday("http://schema.org/Saturday") == .every(.saturday))
        #expect(Schedule.parseWeekday("Wednesday") == .every(.wednesday))
    }

    // MARK: Schedule → RRULE

    @Test("Weekly schedule with byDay produces an RRULE")
    func testToRRule() throws {
        let schedule = Schedule(repeatFrequency: "P1W", byDay: ["MO", "WE"])
        let rrule = try #require(schedule.rrule())

        #expect(rrule.contains("FREQ=WEEKLY"))
        #expect(rrule.contains("MO"))
        #expect(rrule.contains("WE"))
    }

    @Test("Interval, count, and byMonthDay reach the RRULE")
    func testToRRuleDetails() throws {
        let schedule = Schedule(
            repeatFrequency: "P2W",
            repeatCount: 10,
            byMonthDay: [1, 15]
        )
        let rrule = try #require(schedule.rrule())

        #expect(rrule.contains("FREQ=WEEKLY"))
        #expect(rrule.contains("INTERVAL=2"))
        #expect(rrule.contains("COUNT=10"))
        #expect(rrule.contains("BYMONTHDAY="))
    }

    @Test("A schedule without a usable frequency yields no RRULE")
    func testNoFrequencyNoRRule() {
        #expect(Schedule(byDay: ["MO"]).rrule() == nil)
        #expect(Schedule(repeatFrequency: "fortnightly").rrule() == nil)
    }

    // MARK: RRULE → Schedule

    @Test("RRULE round-trips through Schedule for the convertible fields")
    func testRoundTrip() throws {
        let original = "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE"
        let schedule = try #require(Schedule(rrule: original))

        #expect(schedule.repeatFrequency == "P2W")
        #expect(schedule.byDay?.contains("MO") == true)
        #expect(schedule.byDay?.contains("WE") == true)

        let back = try #require(schedule.rrule())
        #expect(back.contains("FREQ=WEEKLY"))
        #expect(back.contains("INTERVAL=2"))
    }

    @Test("COUNT round-trips as repeatCount")
    func testCountRoundTrip() throws {
        let schedule = try #require(Schedule(rrule: "FREQ=DAILY;COUNT=5"))
        #expect(schedule.repeatFrequency == "P1D")
        #expect(schedule.repeatCount == 5)
        #expect(try #require(schedule.rrule()).contains("COUNT=5"))
    }

    @Test("Ordinal weekdays survive a round trip")
    func testOrdinalRoundTrip() throws {
        let schedule = try #require(Schedule(rrule: "FREQ=MONTHLY;BYDAY=-1SU"))
        #expect(schedule.byDay == ["-1SU"])
        #expect(try #require(schedule.rrule()).contains("-1SU"))
    }

    @Test("A malformed RRULE yields nil, not a half-built Schedule")
    func testBadRRule() {
        #expect(Schedule(rrule: "not a rule") == nil)
    }

    // MARK: Codable

    @Test("Schedule decodes from schema.org JSON-LD shapes")
    func testDecodeJSONLD() throws {
        let json = """
        {
          "@type": "Schedule",
          "repeatFrequency": "P1W",
          "byDay": "https://schema.org/Tuesday",
          "byMonth": 6,
          "startTime": "19:00:00",
          "duration": "PT3H"
        }
        """
        let schedule = try JSONDecoder().decode(Schedule.self, from: Data(json.utf8))

        // byDay and byMonth arrive as scalars here, not arrays — both are legal.
        #expect(schedule.byDay == ["https://schema.org/Tuesday"])
        #expect(schedule.byMonth == [6])
        #expect(schedule.startTime == "19:00:00")
        #expect(schedule.duration == "PT3H")
        #expect(try #require(schedule.rrule()).contains("FREQ=WEEKLY"))
    }

    @Test("Non-convertible fields survive an encode/decode round trip")
    func testNonConvertibleFieldsPreserved() throws {
        let original = Schedule(
            repeatFrequency: "P1W",
            byMonthWeek: [2],
            startTime: "09:00:00",
            endTime: "10:00:00",
            duration: "PT1H",
            scheduleTimezone: "America/Los_Angeles"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Schedule.self, from: data)

        #expect(decoded.byMonthWeek == [2])
        #expect(decoded.startTime == "09:00:00")
        #expect(decoded.endTime == "10:00:00")
        #expect(decoded.duration == "PT1H")
        #expect(decoded.scheduleTimezone == "America/Los_Angeles")
    }

    @Test("A mismatched @type is rejected")
    func testTypeMismatch() {
        let json = #"{"@type": "Person", "repeatFrequency": "P1W"}"#
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Schedule.self, from: Data(json.utf8))
        }
    }
}

// MARK: - Plan integration

@Suite("Plan — schedule and occurrence generation")
struct PlanScheduleTests {

    private func date(_ iso: String) throws -> Date {
        try #require(DateTime(string: iso)?.value)
    }

    @Test("Plan.schedule reads the plan's rrule")
    func testScheduleGetter() throws {
        let plan = Plan(name: "Weekly Game", rrule: "FREQ=WEEKLY;BYDAY=FR")
        let schedule = try #require(plan.schedule)

        #expect(schedule.repeatFrequency == "P1W")
        #expect(schedule.byDay == ["FR"])
    }

    @Test("Plan.schedule writes back through to rrule")
    func testScheduleSetter() throws {
        var plan = Plan(name: "Standup")
        plan.schedule = Schedule(repeatFrequency: "P1D", repeatCount: 5)

        let rrule = try #require(plan.rrule)
        #expect(rrule.contains("FREQ=DAILY"))
        #expect(rrule.contains("COUNT=5"))
    }

    @Test("Setting schedule to nil clears the recurrence")
    func testScheduleClear() {
        var plan = Plan(name: "Standup", rrule: "FREQ=DAILY")
        plan.schedule = nil
        #expect(plan.rrule == nil)
    }

    @Test("A plan with no rrule has no schedule")
    func testNoSchedule() {
        #expect(Plan(name: "One-off").schedule == nil)
    }

    @Test("Occurrences are generated from the plan's recurrence")
    func testOccurrenceGeneration() throws {
        let start = try date("2026-01-05T09:00:00Z")
        let plan = Plan(
            identifier: "plan.abc12345",
            name: "Weekly Standup",
            startDate: DateTime(start, timeZone: .gmt),
            endDate: DateTime(start.addingTimeInterval(1800), timeZone: .gmt),
            rrule: "FREQ=WEEKLY"
        )
        let occurrences = plan.occurrences(limit: 3)

        #expect(occurrences.count == 3)
        #expect(occurrences.allSatisfy { $0.name == "Weekly Standup" })
        // Each generated occurrence back-references its plan (the ScheduleItem pattern).
        #expect(occurrences.allSatisfy { $0.plan == .entity(.plan, "plan.abc12345") })
        // The plan's own span becomes each occurrence's duration.
        let first = try #require(occurrences.first)
        let span = try #require(first.endDate?.value).timeIntervalSince(
            try #require(first.startDate?.value)
        )
        #expect(span == 1800)
    }

    @Test("exceptDates remove instances from the generated series")
    func testExceptDatesExcluded() throws {
        let start = try date("2026-01-05T09:00:00Z")
        var plan = Plan(
            identifier: "plan.abc12345",
            name: "Weekly Standup",
            startDate: DateTime(start, timeZone: .gmt),
            rrule: "FREQ=WEEKLY"
        )
        let all = plan.recurrenceDates(limit: 3)
        #expect(all.count == 3)

        // Cancel the second instance.
        plan.exceptDates = [DateTime(all[1], timeZone: .gmt)]
        let remaining = plan.recurrenceDates(limit: 3)

        #expect(remaining.count == 3)
        #expect(!remaining.contains(all[1]))
        #expect(remaining.contains(all[0]))
        #expect(remaining.contains(all[2]))
    }

    @Test("Generation needs both a rule and an anchor date")
    func testGenerationRequirements() throws {
        let start = try date("2026-01-05T09:00:00Z")
        // No rrule.
        #expect(Plan(startDate: DateTime(start)).occurrences(limit: 3).isEmpty)
        // No anchor date.
        #expect(Plan(rrule: "FREQ=WEEKLY").occurrences(limit: 3).isEmpty)
        // Zero limit.
        #expect(
            Plan(startDate: DateTime(start), rrule: "FREQ=WEEKLY")
                .occurrences(limit: 0).isEmpty
        )
    }

    @Test("dueDate anchors generation when startDate is absent")
    func testDueDateAnchor() throws {
        let due = try date("2026-03-01T12:00:00Z")
        let plan = Plan(dueDate: DateTime(due, timeZone: .gmt), rrule: "FREQ=DAILY")
        #expect(plan.recurrenceDates(limit: 2).count == 2)
    }

    @Test("exceptDates round-trip through markdown frontmatter")
    func testExceptDatesFrontmatter() throws {
        let start = try date("2026-01-05T09:00:00Z")
        let original = Plan(
            identifier: "plan.abc12345",
            name: "Weekly Game",
            rrule: "FREQ=WEEKLY;BYDAY=FR",
            exceptDates: [DateTime(start, timeZone: .gmt)]
        )
        let text = try MarkdownDocument(original).string()
        let recovered = try MarkdownDocument(string: text).decode(Plan.self)

        #expect(recovered.rrule == original.rrule)
        #expect(recovered.exceptDates?.count == 1)
        #expect(!text.contains("@type"))
    }
}

// MARK: - RFC 5545 date lists

@Suite("RFC5545DateList — EXDATE parsing")
struct RFC5545DateListTests {

    @Test("UTC, zoned, and date-only EXDATE forms all parse")
    func testParseForms() throws {
        let utc = try #require(RFC5545DateList.parse(["EXDATE:20240101T090000Z"]))
        #expect(utc.count == 1)

        let zoned = try #require(
            RFC5545DateList.parse(["EXDATE;TZID=America/Los_Angeles:20240101T090000"])
        )
        #expect(zoned.count == 1)
        #expect(zoned[0].timeZone?.identifier == "America/Los_Angeles")

        let dateOnly = try #require(RFC5545DateList.parse(["EXDATE;VALUE=DATE:20240101"]))
        #expect(dateOnly.count == 1)
    }

    @Test("Comma-separated values and multiple lines accumulate")
    func testMultipleValues() throws {
        let parsed = try #require(
            RFC5545DateList.parse([
                "EXDATE:20240101T090000Z,20240108T090000Z",
                "EXDATE:20240115T090000Z",
            ])
        )
        #expect(parsed.count == 3)
    }

    @Test("Malformed values are skipped, not fatal")
    func testMalformedSkipped() throws {
        let parsed = try #require(
            RFC5545DateList.parse(["EXDATE:garbage,20240101T090000Z"])
        )
        #expect(parsed.count == 1)
        #expect(RFC5545DateList.parse(["EXDATE:garbage"]) == nil)
        #expect(RFC5545DateList.parse(["no colon here"]) == nil)
        #expect(RFC5545DateList.parse([]) == nil)
    }

    @Test("Formatting emits the unambiguous UTC form and round-trips")
    func testFormatRoundTrip() throws {
        let original = try #require(RFC5545DateList.parse(["EXDATE:20240101T090000Z"]))
        let formatted = try #require(RFC5545DateList.format(original))

        #expect(formatted == "20240101T090000Z")
        let back = try #require(RFC5545DateList.parse(["EXDATE:\(formatted)"]))
        #expect(back[0].value == original[0].value)
    }

    @Test("Nothing to format yields nil")
    func testFormatEmpty() {
        #expect(RFC5545DateList.format(nil) == nil)
        #expect(RFC5545DateList.format([]) == nil)
    }
}

// MARK: - Registry routing

@Suite("SchemaTypeRegistry — eventSchedule routing")
struct EventScheduleRoutingTests {

    private func decode(_ json: String) throws -> any Entity {
        let parsed = try JSON.parse(Data(json.utf8))
        return SchemaTypeRegistry.entity(fromJSONLD: parsed)
    }

    @Test("An Event carrying eventSchedule becomes a Plan with an rrule")
    func testScheduledEventBecomesPlan() throws {
        let entity = try decode("""
        {
          "@type": "Event",
          "name": "Farmers Market",
          "location": { "@type": "Place", "name": "Town Square" },
          "eventSchedule": {
            "@type": "Schedule",
            "repeatFrequency": "P1W",
            "byDay": "https://schema.org/Saturday",
            "startDate": "2026-05-02"
          }
        }
        """)

        let plan = try #require(entity as? Plan)
        #expect(plan.name == "Farmers Market")
        // Plan.location is already a Place, so the object needs no remapping.
        #expect(plan.location?.name == "Town Square")
        #expect(try #require(plan.rrule).contains("FREQ=WEEKLY"))
        #expect(try #require(plan.rrule).contains("SA"))
        // The schedule's startDate seeds the plan's.
        #expect(plan.startDate != nil)
        // Registry always mints an id so search UIs have something stable.
        #expect(plan.identifier != nil)
    }

    @Test("A plain Event still becomes an Occurrence — no regression")
    func testPlainEventStillOccurrence() throws {
        let entity = try decode("""
        {
          "@type": "Event",
          "name": "Book Launch",
          "startDate": "2026-06-30T19:00:00Z",
          "location": { "@type": "Place", "name": "City Library" }
        }
        """)

        let occurrence = try #require(entity as? Occurrence)
        #expect(occurrence.name == "Book Launch")
        #expect(occurrence.place?.name == "City Library")
    }

    @Test("An Event whose schedule has no usable frequency keeps the raw schedule")
    func testUnusableScheduleFallsBack() throws {
        let entity = try decode("""
        {
          "@type": "Event",
          "name": "Odd One",
          "eventSchedule": { "@type": "Schedule", "repeatFrequency": "fortnightly" }
        }
        """)

        // No rrule could be built, so this is not a recurrence the hub can model —
        // it decodes as a Plan with the raw schedule preserved in meta.
        let plan = try #require(entity as? Plan)
        #expect(plan.rrule == nil)
        #expect(plan.meta?["eventSchedule"] != nil)
    }

    @Test("Scheduled subtypes route the same way as Event")
    func testSubtypeRouting() throws {
        let entity = try decode("""
        {
          "@type": "MusicEvent",
          "name": "Open Mic",
          "eventSchedule": { "@type": "Schedule", "repeatFrequency": "P1W" }
        }
        """)
        #expect(entity is Plan)
    }
}
