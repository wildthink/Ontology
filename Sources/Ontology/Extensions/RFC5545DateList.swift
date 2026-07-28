import Foundation

/// Parsing and formatting for RFC 5545 date-list properties (`EXDATE`, `RDATE`).
///
/// These live on their own content lines rather than inside an RRULE, so they are
/// not covered by `RecurrenceRuleRFC5545FormatStyle` — that style handles the rule
/// itself. `Plan.exceptDates` is the hub-side storage.
///
/// Handles the three value forms in the wild:
/// - `EXDATE:20240101T090000Z` — UTC
/// - `EXDATE;TZID=America/Los_Angeles:20240101T090000` — zoned, floating local time
/// - `EXDATE;VALUE=DATE:20240101` — date only
///
/// Multiple comma-separated values per line are supported, as are multiple lines.
public enum RFC5545DateList {

    /// Parse `EXDATE`/`RDATE` content lines into dates.
    ///
    /// Unparseable values are skipped rather than failing the whole line — calendar
    /// feeds in the wild carry occasional malformed entries, and losing one
    /// exception date is better than losing the plan.
    ///
    /// - Returns: the parsed dates, or `nil` when there are none (so the result can
    ///   be assigned straight to an optional field without an empty-array sentinel).
    public static func parse(_ lines: [String]) -> [DateTime]? {
        var results: [DateTime] = []

        for line in lines {
            // Split the property name + params from the value list.
            guard let colon = line.firstIndex(of: ":") else { continue }
            let head = line[line.startIndex..<colon]
            let values = line[line.index(after: colon)...]

            // TZID=... in the params selects the zone for floating local times.
            let zone = head
                .split(separator: ";")
                .first { $0.uppercased().hasPrefix("TZID=") }
                .map { String($0.dropFirst(5)) }
                .flatMap { TimeZone(identifier: $0) }

            for raw in values.split(separator: ",") {
                if let dt = parseValue(String(raw), zone: zone) {
                    results.append(dt)
                }
            }
        }
        return results.isEmpty ? nil : results
    }

    /// Format dates as an RFC 5545 value list in UTC basic form.
    ///
    /// Always emits the `Z` (UTC) form — unambiguous and accepted everywhere,
    /// which avoids having to also emit a matching `TZID` parameter.
    ///
    /// - Returns: the comma-joined value list without a property name, or `nil`
    ///   when there is nothing to write.
    public static func format(_ dates: [DateTime]?) -> String? {
        guard let dates, !dates.isEmpty else { return nil }
        return dates.map { utcFormatter.string(from: $0.value) }.joined(separator: ",")
    }

    // MARK: - Internals

    static func parseValue(_ raw: String, zone: TimeZone?) -> DateTime? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasSuffix("Z") {
            return DateTime(utcFormatter.date(from: value), timeZone: .gmt)
        }
        if value.contains("T") {
            let formatter = localFormatter
            formatter.timeZone = zone ?? .current
            return DateTime(formatter.date(from: value), timeZone: zone ?? .current)
        }
        let formatter = dateOnlyFormatter
        formatter.timeZone = zone ?? .current
        return DateTime(formatter.date(from: value), timeZone: zone ?? .current)
    }

    private static func makeFormatter(_ format: String, utc: Bool = false) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        if utc { f.timeZone = .gmt }
        return f
    }

    private static let utcFormatter = makeFormatter("yyyyMMdd'T'HHmmss'Z'", utc: true)
    private static var localFormatter: DateFormatter { makeFormatter("yyyyMMdd'T'HHmmss") }
    private static var dateOnlyFormatter: DateFormatter { makeFormatter("yyyyMMdd") }
}
