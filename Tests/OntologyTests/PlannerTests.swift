import Foundation
import Ontology
import Testing

@Suite("Planner domain model")
struct PlannerTests {

    // MARK: - Plan lifecycle fields

    @Test("Plan encodes and decodes status, owner, participants, dueDate, subject, effort")
    func testPlanRoundTrip() throws {
        let ownerRef = HolonRef.entity(.person, "person.abc123")
        let partnerRef = HolonRef.entity(.person, "person.def456")
        let seedRef = HolonRef.entity(.occurrence, "occurrence.xyz789")

        let plan = Plan(
            identifier: "plan.001",
            name: "Prepare dungeon map",
            description: "Draw the goblin lair for session 12",
            status: "active",
            dueDate: DateTime(Date(timeIntervalSinceReferenceDate: 86400)),
            owner: ownerRef,
            participants: [ownerRef, partnerRef],
            subject: seedRef,
            effort: QuantitativeValue(value: 4, unitCode: "HUR", unitText: "hours")
        )

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)

        #expect(decoded.identifier == "plan.001")
        #expect(decoded.name == "Prepare dungeon map")
        #expect(decoded.status == "active")
        #expect(decoded.owner == ownerRef)
        #expect(decoded.participants?.count == 2)
        #expect(decoded.subject == seedRef)
        #expect(decoded.effort?.value == 4)
        #expect(decoded.effort?.unitText == "hours")
        #expect(decoded.dueDate != nil)
    }

    @Test("Opportunity is a Plan with status 'opportunity' and a subject seed")
    func testOpportunityPattern() throws {
        let externalEvent = HolonRef.entity(.occurrence, "occurrence.gcal_evt001")
        let opportunity = Plan(
            name: "Attend regional LARP gathering",
            status: "opportunity",
            subject: externalEvent
        )

        let data = try JSONEncoder().encode(opportunity)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)

        #expect(decoded.status == "opportunity")
        #expect(decoded.subject == externalEvent)
    }

    @Test("Plan markdown frontmatter includes status and participants")
    func testPlanMarkdownWrite() throws {
        let plan = Plan(
            identifier: "plan.001",
            name: "Campaign planning session",
            status: "planning",
            owner: .entity(.person, "person.gm01")
        )
        let doc = try MarkdownDocument(plan, body: "## Notes\n\nFirst planning session.")
        let text = doc.string()

        #expect(text.contains("status: planning"))
        #expect(text.contains("Campaign planning session"))
    }

    // MARK: - Task

    @Test("Task encodes and decodes with all fields")
    func testTaskRoundTrip() throws {
        let planRef = HolonRef.entity(.plan, "plan.001")
        let assigneeRef = HolonRef.entity(.person, "person.abc123")

        let task = Task(
            identifier: "task.001",
            name: "Draft encounter table",
            description: "Random encounters for the goblin lair",
            plan: planRef,
            assignee: assigneeRef,
            dueDate: DateTime(Date(timeIntervalSinceReferenceDate: 86400)),
            schedulingIntent: .soon,
            status: .inProgress,
            statusChangedAt: DateTime(Date(timeIntervalSinceReferenceDate: 43200)),
            priority: 1
        )

        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)

        #expect(decoded.identifier == "task.001")
        #expect(decoded.name == "Draft encounter table")
        #expect(decoded.plan == planRef)
        #expect(decoded.assignee == assigneeRef)
        #expect(decoded.status == .inProgress)
        #expect(decoded.schedulingIntent == .soon)
        #expect(decoded.statusChangedAt != nil)
        #expect(decoded.priority == 1)
        #expect(decoded.dueDate != nil)
    }

    @Test("Task supports skipped workflow state")
    func testTaskSkippedStatus() throws {
        let task = Task(name: "Superseded work", status: .skipped)
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)

        #expect(decoded.status == .skipped)
    }

    @Test("Task status defaults to .open when missing from JSON")
    func testTaskStatusDefault() throws {
        let json = """
        { "name": "Write notes", "description": "Session recap" }
        """
        let task = try JSONDecoder().decode(Task.self, from: Data(json.utf8))
        #expect(task.status == .open)
    }

    @Test("Task carries effort, completedBy, and the occurrence that is the action")
    func testTaskExecutionFields() throws {
        let assigneeRef = HolonRef.entity(.person, "person.abc123")
        let doerRef = HolonRef.entity(.person, "person.def456")
        let meetingRef = HolonRef.entity(.occurrence, "occurrence.xyz789")

        let task = Task(
            identifier: "task.002",
            name: "Attend the session-zero meeting",
            assignee: assigneeRef,
            completedBy: doerRef,
            occurrence: meetingRef,
            effort: QuantitativeValue(value: 90, unitCode: "MIN", unitText: "minutes"),
            status: .done,
            statusChangedAt: DateTime(Date(timeIntervalSinceReferenceDate: 43200))
        )

        let decoded = try JSONDecoder().decode(Task.self, from: JSONEncoder().encode(task))

        // Who was asked and who actually did it are separate facts.
        #expect(decoded.assignee == assigneeRef)
        #expect(decoded.completedBy == doerRef)
        #expect(decoded.occurrence == meetingRef)
        #expect(decoded.effort?.value == 90)
        #expect(decoded.effort?.unitText == "minutes")
        #expect(decoded.statusChangedAt != nil)
    }

    @Test("The optional supports stay absent when a task doesn't use them")
    func testTaskNeedsNoSupports() throws {
        let task = Task(name: "Buy dice", status: .open)
        let text = String(data: try JSONEncoder().encode(task), encoding: .utf8)!

        #expect(!text.contains("occurrence"))
        #expect(!text.contains("alarms"))
        #expect(!text.contains("effort"))
    }

    // MARK: - Plan completion

    @Test("A plan is completable once no action item is open or in progress")
    func testPlanCompletability() {
        let plan = Plan(identifier: "plan.001", name: "Run the one-shot")

        // An empty checklist is completable.
        #expect(plan.isCompletable(given: []))

        let open = Task(name: "Open", status: .open)
        let inProgress = Task(name: "Working", status: .inProgress)
        let done = Task(name: "Done", status: .done)
        let skipped = Task(name: "Skipped", status: .skipped)
        let cancelled = Task(name: "Cancelled", status: .cancelled)

        #expect(!plan.isCompletable(given: [done, open]))
        #expect(!plan.isCompletable(given: [done, inProgress]))

        // Skipping or cancelling a straggler unblocks the plan.
        #expect(plan.isCompletable(given: [done, skipped, cancelled]))
    }

    @Test("Progress and alarms are advisory — neither blocks plan completion")
    func testProgressAndAlarmsDoNotGateCompletion() {
        var counted = Task(name: "Sessions run", status: .done, goal: 12)
        counted.advance(by: 3)

        let plan = Plan(
            identifier: "plan.002",
            name: "Campaign",
            alarms: [.minutesBefore(60)]
        )

        // Short of its goal, and checked off anyway — the check-off is the truth.
        #expect(counted.fractionComplete == 0.25)
        #expect(plan.isCompletable(given: [counted]))
    }

    // MARK: - Progress on an action item

    @Test("Advancing notes progress without completing the item")
    func testAdvanceDoesNotComplete() {
        var task = Task(name: "Read the manual", goal: 10, unitLabel: "pages")
        #expect(task.fractionComplete == 0)

        task.advance(by: 4)
        // Starting is a real status change; finishing still is not.
        #expect(task.status == .inProgress)
        #expect(task.progress == 4)
        #expect(task.progressUpdatedAt != nil)

        task.advance(by: 6)
        #expect(task.fractionComplete == 1)
        #expect(task.status == .inProgress, "reaching the goal never checks the item off")
    }

    @Test("A plain check-off has no progress to report and ignores advancing")
    func testPlainTaskHasNoProgress() {
        var task = Task(name: "Book the room")
        #expect(!task.isCountable)
        #expect(task.fractionComplete == nil)

        task.advance(by: 3)
        #expect(task.progress == nil)
        #expect(task.status == .open)
    }

    // MARK: - Recording what happened

    @Test("Completing a plan produces a Record that outlives it")
    func testPlanCompletionRecord() throws {
        let planRef = HolonRef.entity(.plan, "plan.001")
        let record = Record(
            identifier: "record.001",
            name: "Session 12 ran",
            subject: planRef,
            outcome: "Party cleared the goblin lair; Mira's character died in the second room.",
            recordedAt: DateTime(Date(timeIntervalSinceReferenceDate: 86400))
        )

        let decoded = try JSONDecoder().decode(Record.self, from: JSONEncoder().encode(record))

        #expect(decoded.subject == planRef)
        #expect(decoded.outcome?.contains("goblin lair") == true)
        #expect(decoded.recordedAt != nil)
    }

    @Test("Task encodes plain fields; JSONLD.object supplies the framing")
    func testTaskEncoding() throws {
        let task = Task(identifier: "task.001", name: "Buy supplies")
        let data = try JSONEncoder().encode(task)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["@type"] == nil)
        #expect(json["@context"] == nil)
        #expect(json["id"] as? String == "task.001")

        let framed = try JSONLD.object(task)
        #expect(framed["@type"]?.string == "Task")
        #expect(framed["@context"]?.string == "https://schema.org")
        #expect(framed["@id"]?.string == "task.001")
    }

    // MARK: - Commitment

    @Test("Commitment encodes and decodes all fields")
    func testCommitmentRoundTrip() throws {
        let planRef = HolonRef.entity(.plan, "plan.001")
        let gmRef = HolonRef.entity(.person, "person.gm01")
        let playerRef = HolonRef.entity(.person, "person.player01")

        let commitment = Commitment(
            identifier: "commitment.001",
            name: "GM invites player to session",
            plan: planRef,
            actor: gmRef,
            recipient: playerRef,
            role: "invitation",
            status: "pending",
            dueDate: DateTime(Date(timeIntervalSinceReferenceDate: 3600)),
            note: "Please RSVP by Friday"
        )

        let data = try JSONEncoder().encode(commitment)
        let decoded = try JSONDecoder().decode(Commitment.self, from: data)

        #expect(decoded.identifier == "commitment.001")
        #expect(decoded.plan == planRef)
        #expect(decoded.actor == gmRef)
        #expect(decoded.recipient == playerRef)
        #expect(decoded.role == "invitation")
        #expect(decoded.status == "pending")
        #expect(decoded.note == "Please RSVP by Friday")
    }

    @Test("Self-commitment has no recipient")
    func testSelfCommitment() throws {
        let selfRef = HolonRef.entity(.person, "person.gm01")
        let c = Commitment(
            name: "Prep miniatures before session",
            actor: selfRef,
            role: "self",
            status: "pending"
        )

        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(Commitment.self, from: data)

        #expect(decoded.recipient == nil)
        #expect(decoded.role == "self")
    }

    @Test("JSONLD.object gives Commitment its @type")
    func testCommitmentJSONLDType() throws {
        let c = Commitment(name: "Attend session")
        #expect(try JSONLD.object(c)["@type"]?.string == "Commitment")
    }

    // MARK: - Taxon

    @Test("Task and Commitment have correct taxon values")
    func testTaxons() {
        #expect(Task.taxon == .task)
        #expect(Commitment.taxon == .commitment)
        #expect(Taxon.task.description == "task")
        #expect(Taxon.commitment.description == "commitment")
    }

    // MARK: - Status vocabulary

    @Test("Plan.Status vocabulary constants are correct strings")
    func testPlanStatusVocabulary() {
        #expect(Plan.Status.opportunity == "opportunity")
        #expect(Plan.Status.planning == "planning")
        #expect(Plan.Status.active == "active")
        #expect(Plan.Status.completed == "completed")
        #expect(Plan.Status.cancelled == "cancelled")
        #expect(Plan.Status.onHold == "on-hold")
    }

    @Test("Commitment.Status and Role vocabulary constants are correct strings")
    func testCommitmentVocabulary() {
        #expect(Commitment.Status.pending == "pending")
        #expect(Commitment.Status.accepted == "accepted")
        #expect(Commitment.Status.declined == "declined")
        #expect(Commitment.Status.completed == "completed")
        #expect(Commitment.Role.invitation == "invitation")
        #expect(Commitment.Role.delegation == "delegation")
        #expect(Commitment.Role.selfCommitment == "self")
    }

    // MARK: - Plan.collection

    @Test("Plan.collection groups task and commitment refs")
    func testPlanCollection() {
        let plan = Plan(identifier: "plan.001", name: "Session prep")
        let taskRef = HolonRef.entity(.task, "task.001")
        let commitRef = HolonRef.entity(.commitment, "commitment.001")

        let col = plan.collection(members: [taskRef, commitRef])

        #expect(col.name == "Session prep")
        #expect(col.identifier == "collection.plan.001")
        #expect(col.members.count == 2)
        #expect(col.members[0] == taskRef)
        #expect(col.members[1] == commitRef)
    }

    @Test("Plan with alarms encodes and decodes")
    func testPlanWithAlarms() throws {
        let plan = Plan(
            name: "Campaign kickoff",
            status: Plan.Status.active,
            dueDate: DateTime(Date(timeIntervalSinceReferenceDate: 86400)),
            alarms: [.minutesBefore(60), .minutesBefore(15, method: "email")]
        )
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(Plan.self, from: data)

        #expect(decoded.status == Plan.Status.active)
        #expect(decoded.alarms?.count == 2)
    }
}
