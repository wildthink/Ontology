#if canImport(EventKit)
import EventKit
import Ontology

// MARK: - Alarm ↔ EKAlarm

extension Alarm {
    /// Create an `Alarm` from an `EKAlarm`.
    public init(_ ekAlarm: EKAlarm) {
        if let date = ekAlarm.absoluteDate {
            self.init(trigger: .absoluteDate(DateTime(date)), method: "display")
        } else {
            let minutes = Int(ekAlarm.relativeOffset / 60)
            self.init(trigger: .offsetMinutes(minutes), method: "display")
        }
    }

    /// Convert this `Alarm` to an `EKAlarm`.
    public func ekAlarm() -> EKAlarm {
        switch trigger {
        case .offsetMinutes(let n):
            return EKAlarm(relativeOffset: TimeInterval(n) * 60)
        case .absoluteDate(let dt):
            return EKAlarm(absoluteDate: dt.value)
        }
    }
}
#endif
