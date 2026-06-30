import Foundation

/// A prompt attached to a Plan, Occurrence, or Task.
///
/// An alarm is a pure value type — it has no independent identity and lives embedded in its
/// parent entity's frontmatter. Two trigger kinds are supported:
///
/// - `.offsetMinutes(n)` — relative to the entity's start/due date. Negative = before, positive = after.
/// - `.absoluteDate(dt)` — fires at a specific moment regardless of the parent date.
///
/// Methods follow EKAlarm / Google Calendar vocabulary: "display", "email", "audio".
public struct Alarm: Hashable, Sendable {
    public enum Trigger: Hashable, Sendable {
        case offsetMinutes(Int)
        case absoluteDate(DateTime)
    }

    public var trigger: Trigger
    /// "display" | "email" | "audio"
    public var method: String?

    public init(trigger: Trigger, method: String? = nil) {
        self.trigger = trigger
        self.method = method
    }

    /// Alarm that fires `n` minutes before the parent entity's start/due date.
    public static func minutesBefore(_ n: Int, method: String? = "display") -> Alarm {
        Alarm(trigger: .offsetMinutes(-abs(n)), method: method)
    }

    /// Alarm at a specific date and time.
    public static func at(_ date: DateTime, method: String? = "display") -> Alarm {
        Alarm(trigger: .absoluteDate(date), method: method)
    }
}

// MARK: - Codable

extension Alarm: Codable {
    private enum CodingKeys: String, CodingKey {
        case method, offsetMinutes, absoluteDate
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(method, forKey: .method)
        switch trigger {
        case .offsetMinutes(let n): try c.encode(n, forKey: .offsetMinutes)
        case .absoluteDate(let dt): try c.encode(dt, forKey: .absoluteDate)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        method = try c.decodeIfPresent(String.self, forKey: .method)
        if let n = try c.decodeIfPresent(Int.self, forKey: .offsetMinutes) {
            trigger = .offsetMinutes(n)
        } else if let dt = try c.decodeIfPresent(DateTime.self, forKey: .absoluteDate) {
            trigger = .absoluteDate(dt)
        } else {
            trigger = .offsetMinutes(-15)
        }
    }
}
