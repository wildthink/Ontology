import Foundation
import Ontology
import Testing

@Test func scoreStartsAtZeroAgainstItsGoal() {
    let score = Score(summary: "Interviews", goal: 5)

    #expect(score.value.value == 0)
    #expect(score.goal.value == 5)
    #expect(score.state == .none)
    #expect(!score.isFinal)
    #expect(score.finalValue == nil)
}

/// `init` used to accept `value:` and `updated:` and assign neither — the starting
/// value was reconstructed from the (now removed) `entries` array instead. With the
/// score mutated in place there is nothing to reconstruct from, so both must stick.
@Test func scoreInitHonoursItsStartingValueAndStamp() {
    let stamped = Date(timeIntervalSince1970: 1_700_000_000)
    let score = Score(summary: "Miles", value: 3, goal: 10, updated: stamped)

    #expect(score.value.value == 3)
    #expect(score.goal.value == 10)
    #expect(score.updated == stamped)
}

/// A score is a live gauge: advancing overwrites the value and moves the stamp
/// forward, keeping no record of where it had been.
@Test func advancingAScoreOverwritesRatherThanAccumulatingHistory() {
    let first = Date(timeIntervalSince1970: 1_700_000_000)
    let second = first.addingTimeInterval(3600)
    var score = Score(summary: "Pages", goal: 10)

    score.advance(by: 4, at: first)
    #expect(score.value.value == 4)
    #expect(score.state == .in_progress)
    #expect(score.updated == first)

    score.advance(by: 3, at: second)
    #expect(score.value.value == 7)
    #expect(score.updated == second)
    #expect(!score.isFinal)

    score.advance(by: 3, at: second)
    #expect(score.isFinal)
}

@Test func finalizingAScoreStampsWhenItHappened() {
    let closed = Date(timeIntervalSince1970: 1_700_000_000)
    var score = Score(summary: "Launch", goal: 1)

    score.setFinalValue(1, at: closed)

    #expect(score.updated == closed)
    #expect(score.isFinal)
}

@Test func scoreSurvivesCodableRoundTrip() throws {
    let recorded = Date(timeIntervalSince1970: 1_700_000_000)
    var score = Score(summary: "Drafts", goal: 3)
    score.setFinalValue(2, at: recorded)

    let data = try JSONEncoder().encode(score)
    let decoded = try JSONDecoder().decode(Score.self, from: data)

    #expect(decoded.id == score.id)
    #expect(decoded.summary == "Drafts")
    #expect(decoded.goal.value == 3)
    #expect(decoded.value.value == 2)
    #expect(decoded.state == .final)
    #expect(decoded.updated == recorded)
}

/// A plain numeric goal produces a dimensionless `Unit.none`, whose symbol
/// only became readable again in Units 7e08ac9. A `Plan` embeds a `ScoreCard`,
/// so a regression there would take plan round-tripping down with it.
@Test func planWithScoreCardRoundTrips() throws {
    var score = Score(summary: "Sessions run", goal: 12)
    score.setFinalValue(3)
    let plan = Plan(identifier: "plan.abc12345", name: "Campaign", scoreCard: [score])

    let data = try JSONEncoder().encode(plan)
    let decoded = try JSONDecoder().decode(Plan.self, from: data)

    #expect(decoded.identifier == "plan.abc12345")
    #expect(decoded.scoreCard.count == 1)
    #expect(decoded.scoreCard.first?.summary == "Sessions run")
    #expect(decoded.scoreCard.first?.goal.value == 12)
    #expect(decoded.scoreCard.first?.value.value == 3)
}

@Test func planWithEmptyScoreCardOmitsTheKey() throws {
    let plan = Plan(identifier: "plan.abc12345", name: "Campaign")
    let text = String(data: try JSONEncoder().encode(plan), encoding: .utf8)!

    #expect(!text.contains("scoreCard"))
    #expect(try JSONDecoder().decode(Plan.self, from: Data(text.utf8)).scoreCard.isEmpty)
}

@Test func scoreFinalizationSetsValueAndState() {
    var score = Score(summary: "Launch", goal: 1)

    score.setFinalValue(1)

    #expect(score.isFinal)
    #expect(score.finalValue?.value == 1)
}

@Test func scoreCardFinalityRequiresScoresAndAllFinal() {
    var first = Score(summary: "First", goal: 1)
    var second = Score(summary: "Second", goal: 1)
    first.setFinalValue(1)

    #expect([Score]().isFinal == false)
    #expect([first, second].isFinal == false)

    second.setFinalValue(1)
    #expect([first, second].isFinal)
}

@Test func scoreCardPartitionsUnfinishedFromFinished() {
    var done = Score(summary: "Done", goal: 1)
    done.setFinalValue(1)
    let open = Score(summary: "Open", goal: 1)
    let skipped = Score(summary: "Skipped", goal: 1, state: .ignore)

    let card: ScoreCard = [done, open, skipped]

    #expect(card.finished.map(\.summary) == ["Done"])
    #expect(card.unfinished.map(\.summary) == ["Open"])
}
