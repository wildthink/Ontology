//
//  Score.swift
//  Ontology
//
//  Created by Jason Jobe on 7/19/26.
//

import Foundation
import Period
import Units

public typealias AnyMeasurement = Units.Measurement

public typealias ScoreCard = [Score]

/// A structured value representing an incremental measurement.
/// Boolean -> goal is 1
///
/// A score is a **live gauge, mutated in place**: it holds a current `value`, a `goal`,
/// and a last-updated stamp, and keeps no entry history. Advancing a score overwrites it.
/// Durable memory of what happened belongs in `Record`, not here — scores overwrite,
/// Records accumulate.
public struct Score: Identifiable, Codable, Hashable, Sendable {

    public enum State: Codable, Hashable, Sendable {
        case none, ignore, in_progress, final
    }

    public var id: String
    public var summary: String
    public var goal: AnyMeasurement
    public var state: State
    public var duration: Period

    public var value: AnyMeasurement
    public var updated: Date?

    public var isFinal: Bool { state == .final }
    public var finalValue: AnyMeasurement? { isFinal ? value : nil }

    /// Move the score by `magnitude`, stamping `updated` and advancing `state` —
    /// reaching the goal finalises, anything else is progress.
    /// Retains no history; the new value overwrites the old.
    mutating public func advance(by magnitude: Double, at dtg: Date = .now) {
        guard magnitude != 0 else { return }
        value = AnyMeasurement(value: value.value + magnitude, unit: value.unit)
        updated = dtg
        if value.value >= goal.value {
            state = .final
        } else if state == .none || state == .final {
            state = .in_progress
        }
    }

    /// Set the score to its closing value and finalise it.
    mutating public func setFinalValue(_ magnitude: Double, at dtg: Date = .now) {
        value = AnyMeasurement(value: magnitude, unit: value.unit)
        updated = dtg
        state = .final
    }

    public init(
        id: String = UUID().uuidString,
        summary: String,
        value: AnyMeasurement? = nil,
        goal: AnyMeasurement,
        updated: Date? = nil,
        duration: Period = .zero,
        state: State = .none
    ) {
        self.id = id
        self.summary = summary
        self.goal = goal
        self.duration = duration
        self.state = state
        self.value = value ?? goal.zero
        self.updated = updated
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case summary
        case goal
        case value
        case state
        case duration
        case updated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        summary = try container.decode(String.self, forKey: .summary)
        goal = try container.decode(AnyMeasurement.self, forKey: .goal)
        value = try container.decode(AnyMeasurement.self, forKey: .value)
        state = try container.decode(State.self, forKey: .state)
        duration = try container.decode(Period.self, forKey: .duration)
        updated = try container.decodeIfPresent(Date.self, forKey: .updated)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(summary, forKey: .summary)
        try container.encode(goal, forKey: .goal)
        try container.encode(value, forKey: .value)
        try container.encode(state, forKey: .state)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(updated, forKey: .updated)
    }
}

public extension ScoreCard {

    var unfinished: Self { filter { !$0.isFinal && $0.state != .ignore } }
    var finished: Self { filter(\.isFinal) }

    var isFinal: Bool {
        !isEmpty && allSatisfy(\.isFinal)
    }
}

extension AnyMeasurement {
    var zero: Self { Self.init(value: 0, unit: self.unit) }
}
