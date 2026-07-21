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
public struct Score: Codable, Hashable, Sendable {
    public var summary: String
    /// The numeric value
    public var value: AnyMeasurement
    public var goal: AnyMeasurement
    
    public var completed: Date?
    public var duration: Period
    
    public var isFinal: Bool { completed != nil }
    public var finalValue: AnyMeasurement? { completed == nil ? nil : value }

    mutating public func setFinalValue(_ magnitude: Double, at dtg: Date = .now) {
        value = Measurement(value: magnitude, unit: goal.unit)
        completed = dtg
    }
    
    public init(
        summary: String,
        value: AnyMeasurement? = nil,
        goal: AnyMeasurement,
        completed: Date? = nil,
        duration: Period = .zero
    ) {
        self.summary = summary
        self.value = value ?? goal.zero
        self.goal = goal
        self.completed = completed
        self.duration = duration
    }
}

public extension ScoreCard {
    
    var unfinshed: Self { self.filter { !$0.isFinal } }
    var finshed: Self   { self.filter { $0.isFinal } }

    var isFinal: Bool {
        reduce(false) { $0 && $1.isFinal }
    }
}

extension AnyMeasurement {
    var zero: Self { Self.init(value: 0, unit: self.unit) }
}
