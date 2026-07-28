import Foundation

public struct DateTime: Hashable, Sendable {
    public var value: Date
    public var timeZone: TimeZone?

    public init(_ value: Date, timeZone: TimeZone? = nil) {
        self.value = value
        self.timeZone = timeZone
    }

    public init?(_ value: Date?, timeZone: TimeZone? = nil) {
        guard let value else { return nil }
        self.value = value
        self.timeZone = timeZone
    }

    /// Parses ISO 8601 leniently: fractional seconds, whole seconds, or a
    /// bare date (`2026-06-30`) all accept — wild-web JSON-LD and hand-authored
    /// frontmatter rarely include fractional seconds.
    public init?(string: String) {
        let formatter = ISO8601DateFormatter()
        let attempts: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate],
        ]
        for options in attempts {
            formatter.formatOptions = options
            if let date = formatter.date(from: string) {
                self.value = date
                self.timeZone = TimeZone(iso8601: string)
                return
            }
        }
        return nil
    }
}

extension DateTime: Codable {
    private enum CodingKeys: String, CodingKey {
        case value
        case timeZone
    }

    /// A user info key that allows overriding the TimeZone used when encoding DateTime values.
    ///
    /// When encoding a DateTime, the TimeZone is determined in the following priority order:
    /// 1. TimeZone from encoder.userInfo[DateTime.timeZoneOverrideKey] (if provided)
    /// 2. TimeZone from the DateTime instance (if specified)
    /// 3. GMT/UTC (default fallback)
    ///
    /// This is particularly useful for ensuring dates are interpreted correctly across different
    /// time zones, or when you want to present all dates in a specific time zone regardless
    /// of how they were originally stored.
    ///
    /// Example usage:
    /// ```
    /// let encoder = JSONEncoder()
    /// encoder.userInfo[DateTime.timeZoneOverrideKey] = TimeZone.current
    /// let encodedData = try encoder.encode(myDateTime)
    /// ```
    public static let timeZoneOverrideKey = CodingUserInfoKey(
        rawValue: "me.mattt.Ontology.DateTimeEncodingTimeZone")!

    /// Decodes an ISO 8601 string. The keyed `{ value: … }` form is still
    /// accepted so documents written before dates became bare strings keep
    /// reading.
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let string = try? container.decode(String.self),
           let date = DateTime(string: string) {
            self = date
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let string = try container.decode(String.self, forKey: .value)
        guard let date = DateTime(string: string) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid date format"
                )
            )
        }
        self = date
    }

    public func encode(to encoder: Encoder) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Check if a TimeZone was provided in userInfo
        if let userInfoTimeZone = encoder.userInfo[DateTime.timeZoneOverrideKey] as? TimeZone {
            formatter.timeZone = userInfoTimeZone
        } else if let timeZone = timeZone {
            formatter.timeZone = timeZone
        } else {
            formatter.timeZone = .gmt
        }

        // Always a bare ISO 8601 string — at the root as well as nested.
        var container = encoder.singleValueContainer()
        try container.encode(formatter.string(from: value))
    }
}
