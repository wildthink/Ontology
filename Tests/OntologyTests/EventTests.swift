import EventKit
import Foundation
import OntologyApple
import Testing

@testable import Ontology

@Suite
struct OccurrenceBridgeTests {
    @Test("Occurrence preserves basic EKEvent properties")
    func testBasicProperties() {
        let store = EKEventStore()
        let ek = EKEvent(eventStore: store)
        ek.title = "Test Event"
        ek.startDate = Date(timeIntervalSinceReferenceDate: 0)
        ek.endDate = Date(timeIntervalSinceReferenceDate: 3600)

        let occ = Occurrence(ek)

        #expect(occ.name == "Test Event")
        #expect(occ.startDate?.value == Date(timeIntervalSinceReferenceDate: 0))
        #expect(occ.endDate?.value == Date(timeIntervalSinceReferenceDate: 3600))
    }

    @Test("Occurrence preserves timezone from EKEvent")
    func testTimezonePreservation() {
        let store = EKEventStore()
        let ek = EKEvent(eventStore: store)
        ek.startDate = Date(timeIntervalSinceReferenceDate: 0)
        ek.endDate = Date(timeIntervalSinceReferenceDate: 3600)
        ek.timeZone = TimeZone(identifier: "America/New_York")!

        let occ = Occurrence(ek)

        #expect(occ.startDate?.timeZone?.identifier == "America/New_York")
        #expect(occ.endDate?.timeZone?.identifier == "America/New_York")
    }

    @Test("Occurrence captures optional EKEvent fields")
    func testOptionalProperties() {
        let store = EKEventStore()
        let ek = EKEvent(eventStore: store)
        ek.title = "Test Event"
        ek.startDate = Date(timeIntervalSinceReferenceDate: 0)
        ek.endDate = Date(timeIntervalSinceReferenceDate: 3600)
        ek.location = "123 Test Street"
        ek.url = URL(string: "https://example.com")

        let occ = Occurrence(ek)

        #expect(occ.location == "123 Test Street")
        #expect(occ.url?.absoluteString == "https://example.com")

        let empty = EKEvent(eventStore: store)
        empty.title = "Minimal"
        empty.startDate = Date(timeIntervalSinceReferenceDate: 0)
        empty.endDate = Date(timeIntervalSinceReferenceDate: 3600)

        let minimal = Occurrence(empty)
        #expect(minimal.location == nil)
        #expect(minimal.url == nil)
    }

    @Test("Occurrence JSON-LD encoding has correct type and fields")
    func testJSONLDEncoding() throws {
        let store = EKEventStore()
        let ek = EKEvent(eventStore: store)
        ek.title = "NYE"
        ek.startDate = Date(timeIntervalSinceReferenceDate: 0)
        ek.endDate = Date(timeIntervalSinceReferenceDate: 3600 * 5)
        ek.timeZone = TimeZone(identifier: "America/New_York")!
        ek.location = "1550 Broadway, New York, NY 10036"
        ek.url = URL(string: "https://example.com")

        let data = try JSONEncoder().encode(Occurrence(ek))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["@context"] as? String == "https://schema.org")
        #expect(json["@type"] as? String == "Occurrence")
        #expect(json["name"] as? String == "NYE")
        #expect(json["location"] as? String == "1550 Broadway, New York, NY 10036")
        #expect(json["url"] as? String == "https://example.com")
        #expect(json["startDate"] as? String == "2000-12-31T19:00:00.000-05:00")
        #expect(json["endDate"] as? String == "2001-01-01T00:00:00.000-05:00")
    }

    @Test("Occurrence JSON-LD round-trip preserves data")
    func testRoundTrip() throws {
        let store = EKEventStore()
        let ek = EKEvent(eventStore: store)
        ek.title = "Test Event"
        ek.startDate = Date(timeIntervalSinceReferenceDate: 0)
        ek.endDate = Date(timeIntervalSinceReferenceDate: 3600)
        ek.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let original = Occurrence(ek)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Occurrence.self, from: encoded)

        #expect(decoded.name == original.name)
        #expect(decoded.startDate?.value == original.startDate?.value)
        #expect(decoded.endDate?.value == original.endDate?.value)
        #expect(decoded.startDate?.timeZone?.secondsFromGMT() == -8 * 3600)
        #expect(decoded.endDate?.timeZone?.secondsFromGMT() == -8 * 3600)
    }
}
