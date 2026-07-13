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

        var plan = Plan(
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

    @Test("Task JSON-LD encoding has correct @type")
    func testTaskJSONLDType() throws {
        let task = Task(name: "Buy supplies")
        let data = try JSONEncoder().encode(task)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["@type"] as? String == "Task")
        #expect(json["@context"] as? String == "https://schema.org")
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

    @Test("Commitment JSON-LD encoding has correct @type")
    func testCommitmentJSONLDType() throws {
        let c = Commitment(name: "Attend session")
        let data = try JSONEncoder().encode(c)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["@type"] as? String == "Commitment")
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
