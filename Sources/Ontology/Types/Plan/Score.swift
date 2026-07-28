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

/// A structured value representing an incremental measurement
/// Boolean -> goal is 1
public struct Score: Identifiable, Codable, Hashable, Sendable {
//    public struct Entry: Identifiable, Codable, Hashable, Sendable {
//        public let id: Int
//        public let increment: AnyMeasurement
//        public let recordedAt: Date
//        public let note: String?
//
//        public init(
//            id: Int,
//            increment: AnyMeasurement,
//            recordedAt: Date = .now,
//            note: String? = nil
//        ) {
//            self.id = id
//            self.increment = increment
//            self.recordedAt = recordedAt
//            self.note = note
//        }
//
//        private enum CodingKeys: String, CodingKey {
//            case id
//            case magnitude
//            case unit
//            case recordedAt
//            case note
//        }
//
//        public init(from decoder: Decoder) throws {
//            let container = try decoder.container(keyedBy: CodingKeys.self)
//            id = try container.decode(Int.self, forKey: .id)
//            let magnitude = try container.decode(Double.self, forKey: .magnitude)
//            let symbol = try container.decode(String.self, forKey: .unit)
//            guard let unit = Unit(symbol) else {
//                throw DecodingError.dataCorruptedError(
//                    forKey: .unit,
//                    in: container,
//                    debugDescription: "Unknown score unit: \(symbol)"
//                )
//            }
//            increment = Measurement(value: magnitude, unit: unit)
//            recordedAt = try container.decode(Date.self, forKey: .recordedAt)
//            note = try container.decodeIfPresent(String.self, forKey: .note)
//        }
//
//        public func encode(to encoder: Encoder) throws {
//            var container = encoder.container(keyedBy: CodingKeys.self)
//            try container.encode(id, forKey: .id)
//            try container.encode(increment.value, forKey: .magnitude)
//            try container.encode(increment.unit.symbol, forKey: .unit)
//            try container.encode(recordedAt, forKey: .recordedAt)
//            try container.encodeIfPresent(note, forKey: .note)
//        }
//    }

    public enum State: Codable, Hashable, Sendable {
        case none, ignore, in_progress, final
    }

    public var id: String
    public var summary: String
    public var goal: AnyMeasurement
//    public private(set) var entries: [Entry]
    public var state: State
    public var duration: Period

    public var value: AnyMeasurement
    public var updated: Date?
//    {
//        Measurement(
//            value: entries.reduce(0) { $0 + $1.increment.value },
//            unit: goal.unit
//        )
//    }

//    public var updated: Date? { entries.last?.recordedAt }
    public var isFinal: Bool { state == .final }
    public var finalValue: AnyMeasurement? { isFinal ? value : nil }

    /// Move the score by `magnitude`, stamping `updated` and advancing `state`
    /// the way the removed `record(_:)` did — reaching the goal finalises,
    /// anything else is progress. Kept because the UI needs an increment verb;
    /// unlike `record(_:)` it retains no entry history.
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

    mutating public func setFinalValue(_ magnitude: Double, at dtg: Date = .now) {
        value = AnyMeasurement(value: magnitude, unit: value.unit)
//        record(magnitude - value.value, at: dtg)
        state = .final
    }

//    @discardableResult
//    mutating public func record(
//        _ magnitude: Double,
//        at recordedAt: Date = .now,
//        note: String? = nil
//    ) -> Entry? {
//        guard magnitude != 0 else { return nil }
//        let entry = Entry(
//            id: (entries.last?.id ?? 0) + 1,
//            increment: Measurement(value: magnitude, unit: goal.unit),
//            recordedAt: recordedAt,
//            note: note
//        )
//        entries.append(entry)
//        if value.value >= goal.value {
//            state = .final
//        } else if state == .none || state == .final {
//            state = .in_progress
//        }
//        return entry
//    }
//    
    public init(
        id: String = UUID().uuidString,
        summary: String,
        value: AnyMeasurement? = nil,
        goal: AnyMeasurement,
        updated: Date? = nil,
        duration: Period = .zero,
        state: State = .none
//        entries: [Entry] = []
    ) {
        self.id = id
        self.summary = summary
        self.goal = goal
        self.duration = duration
        self.state = state
        self.value = goal.zero
//        if entries.isEmpty, let value, value.value != 0 {
//            self.entries = [
//                Entry(
//                    id: 1,
//                    increment: Measurement(value: value.value, unit: goal.unit),
//                    recordedAt: updated ?? .now
//                )
//            ]
//        } else {
//            self.entries = entries
//        }
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
//        let goalMagnitude = try container.decode(Double.self, forKey: .goalMagnitude)
//        let goalSymbol = try container.decode(String.self, forKey: .goalUnit)
//        guard let goalUnit = Unit(goalSymbol) else {
//            throw DecodingError.dataCorruptedError(
//                forKey: .goalUnit,
//                in: container,
//                debugDescription: "Unknown score unit: \(goalSymbol)"
//            )
//        }
//        goal = Measurement(value: goalMagnitude, unit: goalUnit)
//        entries = try container.decode([Entry].self, forKey: .entries)
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
