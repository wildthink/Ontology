import Foundation
import Ontology
import OntologyOKF
import Testing

/// Smoke tests confirming that Task and Commitment round-trip through the OKF
/// markdown/YAML exchange format without data loss.
@Suite("OKF — Task and Commitment exchange format")
struct OKFPlannerTests {

    // MARK: - Task

    @Test("Task writes and reads back via OKF markdown")
    func testTaskOKFRoundTrip() throws {
        let task = Task(
            identifier: "task.001",
            name: "Draft encounter table",
            description: "Random encounters for the goblin lair",
            dueDate: DateTime(Date(timeIntervalSinceReferenceDate: 86400), timeZone: .gmt),
            status: .inProgress,
            priority: 1,
            alarms: [.minutesBefore(60)]
        )

        let doc = try OKFDocument(task, body: "## Details\n\nNeed 12 entries.")
        let text = doc.string()

        // Spot-check the YAML frontmatter
        #expect(text.contains("Draft encounter table"))
        #expect(text.contains("inProgress"))

        // Round-trip through the reader
        let decoded = try OKFReader.decode(Task.self, from: text)
        #expect(decoded.name == task.name)
        #expect(decoded.description == task.description)
        #expect(decoded.status == .inProgress)
        #expect(decoded.priority == 1)
    }

    @Test("Task execution fields survive the OKF markdown round trip")
    func testTaskExecutionFieldsOKFRoundTrip() throws {
        let doerRef = HolonRef.entity(.person, "person.def456")
        let meetingRef = HolonRef.entity(.occurrence, "occurrence.xyz789")

        let task = Task(
            identifier: "task.002",
            name: "Attend the session-zero meeting",
            completedBy: doerRef,
            occurrence: meetingRef,
            effort: QuantitativeValue(value: 90, unitCode: "MIN", unitText: "minutes"),
            status: .done
        )

        let text = try OKFDocument(task, body: "Ran long, but everyone showed.").string()
        let decoded = try OKFReader.decode(Task.self, from: text)

        #expect(decoded.completedBy == doerRef)
        #expect(decoded.occurrence == meetingRef)
        #expect(decoded.effort?.value == 90)
        #expect(decoded.status == .done)
    }

    @Test("Record writes and reads back via OKF markdown")
    func testRecordOKFRoundTrip() throws {
        let planRef = HolonRef.entity(.plan, "plan.001")
        let record = Record(
            identifier: "record.001",
            name: "Session 12 ran",
            subject: planRef,
            outcome: "Party cleared the goblin lair.",
            recordedAt: DateTime(Date(timeIntervalSinceReferenceDate: 86400), timeZone: .gmt)
        )

        let text = try OKFDocument(record, body: "## Notes\n\nMira's character died.").string()
        #expect(text.contains("Session 12 ran"))

        let decoded = try OKFReader.decode(Record.self, from: text)
        #expect(decoded.subject == planRef)
        #expect(decoded.outcome == "Party cleared the goblin lair.")
        #expect(decoded.recordedAt != nil)
    }

    @Test("Task writes and reads back via OKFBundle")
    func testTaskOKFBundleRoundTrip() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("OKFPlannerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let bundle = OKFBundle(root: tmp)

        let task = Task(
            identifier: "task.002",
            name: "Paint miniatures",
            status: .open
        )
        try bundle.write(task, to: "tasks/task.002.md")

        let decoded = try OKFReader.decode(
            Task.self,
            contentsOf: tmp.appendingPathComponent("tasks/task.002.md")
        )
        #expect(decoded.name == "Paint miniatures")
        #expect(decoded.status == .open)
    }

    // MARK: - Commitment

    @Test("Commitment writes and reads back via OKF markdown")
    func testCommitmentOKFRoundTrip() throws {
        let planRef = HolonRef.entity(.plan, "plan.001")
        let gmRef = HolonRef.entity(.person, "person.gm01")

        let commitment = Commitment(
            identifier: "commitment.001",
            name: "GM confirms session date",
            plan: planRef,
            actor: gmRef,
            role: Commitment.Role.selfCommitment,
            status: Commitment.Status.pending,
            note: "Tentatively the 15th"
        )

        let doc = try OKFDocument(commitment)
        let text = doc.string()

        #expect(text.contains("GM confirms session date"))
        #expect(text.contains("pending"))

        let decoded = try OKFReader.decode(Commitment.self, from: text)
        #expect(decoded.name == commitment.name)
        #expect(decoded.role == Commitment.Role.selfCommitment)
        #expect(decoded.status == Commitment.Status.pending)
        #expect(decoded.note == "Tentatively the 15th")
        #expect(decoded.plan == planRef)
        #expect(decoded.actor == gmRef)
    }

    // MARK: - Plan with new fields

    @Test("Plan with status, owner, participants, effort writes and reads back via OKF")
    func testPlanOKFRoundTrip() throws {
        let ownerRef = HolonRef.entity(.person, "person.gm01")
        let playerRef = HolonRef.entity(.person, "person.player01")

        let plan = Plan(
            identifier: "plan.001",
            name: "Session 12 preparation",
            status: Plan.Status.active,
            dueDate: DateTime(Date(timeIntervalSinceReferenceDate: 604800), timeZone: .gmt),
            owner: ownerRef,
            participants: [ownerRef, playerRef],
            effort: QuantitativeValue(value: 3, unitCode: "HUR", unitText: "hours"),
            alarms: [.minutesBefore(120)]
        )

        let doc = try OKFDocument(plan, body: "## Notes\n\nPrep session.")
        let text = doc.string()

        #expect(text.contains("Session 12 preparation"))
        #expect(text.contains("active"))

        let decoded = try OKFReader.decode(Plan.self, from: text)
        #expect(decoded.name == plan.name)
        #expect(decoded.status == Plan.Status.active)
        #expect(decoded.owner == ownerRef)
        #expect(decoded.participants?.count == 2)
        #expect(decoded.effort?.value == 3)
        #expect(decoded.alarms?.count == 1)
    }
}
