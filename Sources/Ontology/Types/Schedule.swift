import Foundation

/// A recurrence specification, following schema.org/Schedule.
///
/// `Schedule` is a **value type** — it has no independent identity and lives embedded
/// in its parent's frontmatter, like `Alarm` or `QuantitativeValue`. It is the
/// schema.org-shaped *view* onto a recurrence; the hub's canonical storage remains
/// the RFC 5545 RRULE string in `Plan.rrule`. Use `Plan.schedule` to read or write a
/// plan's recurrence in schema.org terms without a second source of truth.
///
/// ## Fidelity
///
/// Round-tripping goes through `Calendar.RecurrenceRule`, so only the fields with a
/// clean RFC 5545 equivalent survive a conversion:
///
/// | schema.org | RFC 5545 | Converted |
/// |---|---|---|
/// | `repeatFrequency` | `FREQ` + `INTERVAL` | ✅ |
/// | `repeatCount` | `COUNT` | ✅ |
/// | `endDate` | `UNTIL` | ✅ |
/// | `byDay` | `BYDAY` | ✅ |
/// | `byMonth` | `BYMONTH` | ✅ |
/// | `byMonthDay` | `BYMONTHDAY` | ✅ |
/// | `byMonthWeek` | — | ❌ carried, not converted |
/// | `startTime` / `endTime` / `duration` | — | ❌ carried, not converted |
/// | `exceptDate` | `EXDATE` (separate line) | see `Plan.exceptDates` |
///
/// The uncoverted fields are preserved on the value so nothing is lost when a
/// `Schedule` is decoded from wild JSON-LD and re-encoded — they simply do not
/// participate in `rrule`. `byMonthWeek` (week-of-month) has no RFC 5545 counterpart;
/// `BYWEEKNO` is week-of-*year* and would be wrong.
public struct Schedule: Hashable, Sendable {
    /// How often the event repeats: an ISO 8601 duration (`"P1W"`, `"P2D"`) or a
    /// bare word (`"weekly"`, `"daily"`). Both forms appear in the wild.
    public var repeatFrequency: String?
    /// Number of times the event repeats. Maps to `COUNT`.
    public var repeatCount: Int?
    /// Days of the week. Accepts RFC 5545 tokens (`"MO"`, `"2FR"`, `"-1SU"`) or
    /// schema.org `DayOfWeek` URLs (`"https://schema.org/Monday"`).
    public var byDay: [String]?
    /// Months of the year, 1–12.
    public var byMonth: [Int]?
    /// Days of the month, 1–31 (negative counts from the end).
    public var byMonthDay: [Int]?
    /// Weeks of the month. Carried but not converted — no RFC 5545 equivalent.
    public var byMonthWeek: [Int]?
    /// First moment the schedule is in effect.
    public var startDate: DateTime?
    /// Last moment the schedule is in effect. Maps to `UNTIL`.
    public var endDate: DateTime?
    /// Time of day the event starts, e.g. `"09:00:00"`. Carried, not converted.
    public var startTime: String?
    /// Time of day the event ends. Carried, not converted.
    public var endTime: String?
    /// ISO 8601 duration of each occurrence, e.g. `"PT1H"`. Carried, not converted.
    public var duration: String?
    /// IANA timezone identifier the schedule is expressed in.
    public var scheduleTimezone: String?
    /// Dates excluded from the recurrence. Maps to `EXDATE`, which lives on a
    /// separate RFC 5545 line — see `Plan.exceptDates`.
    public var exceptDate: [DateTime]?

    public init(
        repeatFrequency: String? = nil,
        repeatCount: Int? = nil,
        byDay: [String]? = nil,
        byMonth: [Int]? = nil,
        byMonthDay: [Int]? = nil,
        byMonthWeek: [Int]? = nil,
        startDate: DateTime? = nil,
        endDate: DateTime? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        duration: String? = nil,
        scheduleTimezone: String? = nil,
        exceptDate: [DateTime]? = nil
    ) {
        self.repeatFrequency = repeatFrequency
        self.repeatCount = repeatCount
        self.byDay = byDay
        self.byMonth = byMonth
        self.byMonthDay = byMonthDay
        self.byMonthWeek = byMonthWeek
        self.startDate = startDate
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.scheduleTimezone = scheduleTimezone
        self.exceptDate = exceptDate
    }
}

// MARK: - RFC 5545 conversion

extension Schedule {
    /// This schedule as an RFC 5545 RRULE string, or `nil` when `repeatFrequency`
    /// is absent or unrecognised (a recurrence without a frequency is meaningless).
    ///
    /// The string is produced by `Calendar.RecurrenceRule`'s RFC 5545 format style,
    /// so ordinal weekday encoding (`-1SU`), `UNTIL` formatting, and list joining
    /// are handled there rather than here.
    public func rrule(calendar: Calendar = .current) -> String? {
        guard let rule = recurrenceRule(calendar: calendar) else { return nil }
        return rule.formatted(.rfc5545(calendar: calendar))
    }

    /// This schedule as a `Calendar.RecurrenceRule`, or `nil` when `repeatFrequency`
    /// is absent or unrecognised.
    public func recurrenceRule(calendar: Calendar = .current) -> Calendar.RecurrenceRule? {
        guard let (frequency, interval) = Self.parseFrequency(repeatFrequency) else { return nil }

        let end: Calendar.RecurrenceRule.End
        if let repeatCount {
            end = .afterOccurrences(repeatCount)
        } else if let endDate {
            end = .afterDate(endDate.value)
        } else {
            end = .never
        }

        return Calendar.RecurrenceRule(
            calendar: calendar,
            frequency: frequency,
            interval: interval,
            end: end,
            months: (byMonth ?? []).map { Calendar.RecurrenceRule.Month($0) },
            daysOfTheMonth: byMonthDay ?? [],
            weekdays: (byDay ?? []).compactMap(Self.parseWeekday)
        )
    }

    /// Build a `Schedule` from an RFC 5545 RRULE string. Returns `nil` when the
    /// string does not parse.
    ///
    /// Parsing is delegated to the vendored RFC 5545 parse strategy, so weekday
    /// tokens, ordinals, and `UNTIL` dates are handled there.
    public init?(rrule: String, calendar: Calendar = .current) {
        guard let rule = try? Calendar.RecurrenceRule(rrule, strategy: .rfc5545(calendar: calendar))
        else { return nil }
        self.init(rule, calendar: calendar)
    }

    /// Build a `Schedule` from a parsed `Calendar.RecurrenceRule`.
    public init(_ rule: Calendar.RecurrenceRule, calendar: Calendar = .current) {
        self.init(
            repeatFrequency: Self.isoDuration(for: rule.frequency, interval: rule.interval),
            byDay: rule.weekdays.isEmpty ? nil : rule.weekdays.map(Self.token(for:)),
            byMonth: rule.months.isEmpty ? nil : rule.months.map(\.index),
            byMonthDay: rule.daysOfTheMonth.isEmpty ? nil : rule.daysOfTheMonth,
            scheduleTimezone: calendar.timeZone.identifier
        )
        // `RecurrenceRule.End` is a struct with optional accessors, not an enum.
        if #available(iOS 18.2, *) {
            if let occurrences = rule.end.occurrences {
                repeatCount = occurrences
            } else if let until = rule.end.date {
                endDate = DateTime(until, timeZone: calendar.timeZone)
            }
        } else {
            // Fallback on earlier versions
        }
    }

    // MARK: Frequency

    /// Parse schema.org `repeatFrequency` into an RFC 5545 frequency + interval.
    ///
    /// Accepts ISO 8601 durations (`"P2W"` → weekly every 2) and the bare English
    /// words schema.org examples use (`"weekly"` → weekly every 1). Returns `nil`
    /// for anything else.
    ///
    /// Compound durations take their **first** component only — `"P1Y2M"` reads as
    /// yearly. RFC 5545 has a single `FREQ`, so there is nothing to map the rest
    /// onto; the original string stays on `repeatFrequency` either way.
    static func parseFrequency(_ raw: String?) -> (Calendar.RecurrenceRule.Frequency, Int)? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }

        // Bare word form.
        switch raw.lowercased() {
        case "minutely": return (.minutely, 1)
        case "hourly":   return (.hourly, 1)
        case "daily":    return (.daily, 1)
        case "weekly":   return (.weekly, 1)
        case "monthly":  return (.monthly, 1)
        case "yearly", "annually": return (.yearly, 1)
        default: break
        }

        // ISO 8601 duration form: P[n]Y|M|W|D, or PT[n]H|M.
        guard raw.hasPrefix("P") else { return nil }
        let body = raw.dropFirst()
        let isTime = body.hasPrefix("T")
        let payload = isTime ? body.dropFirst() : body
        let digits = payload.prefix { $0.isNumber }
        guard let n = Int(digits), n > 0 else { return nil }
        guard let unit = payload.dropFirst(digits.count).first else { return nil }

        switch (isTime, unit) {
        case (false, "Y"): return (.yearly, n)
        case (false, "M"): return (.monthly, n)
        case (false, "W"): return (.weekly, n)
        case (false, "D"): return (.daily, n)
        case (true,  "H"): return (.hourly, n)
        case (true,  "M"): return (.minutely, n)
        default: return nil
        }
    }

    /// Render a frequency + interval back as an ISO 8601 duration.
    static func isoDuration(
        for frequency: Calendar.RecurrenceRule.Frequency,
        interval: Int
    ) -> String {
        let n = max(interval, 1)
        switch frequency {
        case .minutely: return "PT\(n)M"
        case .hourly:   return "PT\(n)H"
        case .daily:    return "P\(n)D"
        case .weekly:   return "P\(n)W"
        case .monthly:  return "P\(n)M"
        case .yearly:   return "P\(n)Y"
        @unknown default: return "P\(n)D"
        }
    }

    // MARK: Weekdays

    private static let weekdayTokens: [(String, Locale.Weekday)] = [
        ("MO", .monday), ("TU", .tuesday), ("WE", .wednesday), ("TH", .thursday),
        ("FR", .friday), ("SA", .saturday), ("SU", .sunday),
    ]

    /// Parse a `byDay` entry into a recurrence weekday.
    ///
    /// Accepts both forms found in the wild: RFC 5545 tokens with an optional
    /// ordinal prefix (`"MO"`, `"2FR"`, `"-1SU"`) and schema.org `DayOfWeek` URLs
    /// (`"https://schema.org/Monday"`, or the bare name `"Monday"`).
    static func parseWeekday(_ raw: String) -> Calendar.RecurrenceRule.Weekday? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }

        // schema.org DayOfWeek: a URL or a bare English day name.
        let leaf = value.split(separator: "/").last.map(String.init) ?? value
        if let day = weekdayTokens.first(where: {
            $0.1.dayName.caseInsensitiveCompare(leaf) == .orderedSame
        })?.1 {
            return .every(day)
        }

        // RFC 5545: optional signed ordinal, then a two-letter token.
        let ordinalText = value.prefix { $0 == "-" || $0 == "+" || $0.isNumber }
        let token = value.dropFirst(ordinalText.count).uppercased()
        guard let day = weekdayTokens.first(where: { $0.0 == token })?.1 else { return nil }
        if ordinalText.isEmpty { return .every(day) }
        guard let ordinal = Int(ordinalText) else { return nil }
        return .nth(ordinal, day)
    }

    /// Render a recurrence weekday as an RFC 5545 `BYDAY` token.
    static func token(for weekday: Calendar.RecurrenceRule.Weekday) -> String {
        switch weekday {
        case .every(let day):
            return weekdayTokens.first(where: { $0.1 == day })?.0 ?? "MO"
        case .nth(let n, let day):
            let token = weekdayTokens.first(where: { $0.1 == day })?.0 ?? "MO"
            return "\(n)\(token)"
        @unknown default:
            return "MO"
        }
    }
}

extension Locale.Weekday {
    /// The English day name, used to match schema.org `DayOfWeek` values.
    fileprivate var dayName: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        @unknown default: "Monday"
        }
    }
}

// MARK: - Codable

extension Schedule: Codable {
    private enum CodingKeys: String, CodingKey {
        case repeatFrequency, repeatCount
        case byDay, byMonth, byMonthDay, byMonthWeek
        case startDate, endDate, startTime, endTime, duration
        case scheduleTimezone, exceptDate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `repeatFrequency` arrives as a duration string or, in sloppy records, a
        // bare number of days; `byDay`/`byMonth*` are singular-or-array like every
        // other repeatable schema.org property.
        repeatFrequency = try c.decodeStringLeniently(forKey: .repeatFrequency)
        repeatCount = try c.value(.repeatCount)
        byDay = c.decodeFlexibleStringList(forKey: .byDay)
        byMonth = c.decodeFlexibleIntList(forKey: .byMonth)
        byMonthDay = c.decodeFlexibleIntList(forKey: .byMonthDay)
        byMonthWeek = c.decodeFlexibleIntList(forKey: .byMonthWeek)
        startDate = try c.value(.startDate)
        endDate = try c.value(.endDate)
        startTime = try c.decodeStringLeniently(forKey: .startTime)
        endTime = try c.decodeStringLeniently(forKey: .endTime)
        duration = try c.decodeStringLeniently(forKey: .duration)
        scheduleTimezone = try c.decodeStringLeniently(forKey: .scheduleTimezone)
        exceptDate = try c.value(.exceptDate)
    }
}
