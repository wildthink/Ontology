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

@Test func scoreSurvivesCodableRoundTrip() throws {
    let recorded = Date(timeIntervalSince1970: 1_700_000_000)
    var score = Score(summary: "Drafts", goal: 3)
    score.setFinalValue(2, at: recorded)
    score.updated = recorded

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
