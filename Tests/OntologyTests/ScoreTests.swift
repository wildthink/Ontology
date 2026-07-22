import Foundation
import Ontology
import Testing

@Test func scoreRecordsEmbeddedEntriesWithLocalSequence() {
    var score = Score(summary: "Interviews", goal: 5)

    let first = score.record(1, note: "Jamie")
    let second = score.record(2, note: "Design partners")

    #expect(first?.id == 1)
    #expect(second?.id == 2)
    #expect(score.value.value == 3)
    #expect(score.entries.map(\.id) == [1, 2])
}

@Test func scoreSequenceSurvivesCodableRoundTrip() throws {
    var score = Score(summary: "Drafts", goal: 3)
    score.record(1)
    let data = try JSONEncoder().encode(score)
    var decoded = try JSONDecoder().decode(Score.self, from: data)

    decoded.record(1)

    #expect(decoded.entries.map(\.id) == [1, 2])
}

@Test func scoreFinalizationPreservesEntryHistory() {
    let completion = Date(timeIntervalSince1970: 1_700_000_000)
    var score = Score(summary: "Launch", goal: 1)

    score.setFinalValue(1, at: completion)

    #expect(score.isFinal)
    #expect(score.entries.count == 1)
    #expect(score.entries.first?.recordedAt == completion)
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
