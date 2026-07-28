public enum JSONLDCodingKey<T: CodingKey>: CodingKey {
    case context
    case type
    case id
    case attribute(T)

    public var stringValue: String {
        switch self {
        case .context: return "@context"
        case .type: return "@type"
        case .id: return "@id"
        case .attribute(let key): return key.stringValue
        }
    }

    public init?(stringValue: String) {
        switch stringValue {
        case "@context": self = .context
        case "@type": self = .type
        case "@id": self = .id
        default:
            // Try to initialize the underlying key type
            if let key = T(stringValue: stringValue) {
                self = .attribute(key)
            } else {
                return nil
            }
        }
    }

    public var intValue: Int? { nil }
    public init?(intValue: Int) { nil }
}

// MARK: - JSON-LD header

/// The three JSON-LD framing keys (`@context`, `@type`, `@id`) are written and
/// validated identically by every hub type. These helpers are the single
/// enforcement point: a type either calls them or visibly does not, which is
/// what keeps the rule from drifting the way hand-written copies did.
extension KeyedEncodingContainer {
    /// Writes the JSON-LD header: `@context` (root only), `@type`, and `@id`.
    ///
    /// - Parameters:
    ///   - type: the Swift type being encoded — its name becomes `@type`.
    ///   - id: the entity's `identifier`, written as `@id` when present.
    ///   - encoder: used to detect root position (`codingPath.isEmpty`), since
    ///     `@context` belongs only at the top of a document.
    public mutating func encodeJSONLDHeader<Attribute>(
        _ type: Any.Type,
        id: String? = nil,
        encoder: Encoder
    ) throws where Key == JSONLDCodingKey<Attribute> {
        if encoder.codingPath.isEmpty {
            try encode(schema.org, forKey: .context)
        }
        try encode(String(describing: type), forKey: .type)
        try encodeIfPresent(id, forKey: .id)
    }
}

extension KeyedDecodingContainer {
    /// Validates the JSON-LD `@type` when present and returns the decoded `@id`.
    ///
    /// `@type` is absent in YAML frontmatter and stripped from wild-web records
    /// by `SchemaTypeRegistry`, so absence is always valid; only a *present and
    /// mismatched* `@type` throws. This is the `decodeIfPresent` rule that every
    /// hub type is required to follow, in one callable place.
    ///
    /// - Parameter type: the Swift type being decoded — its name is the expected `@type`.
    /// - Returns: the `@id` value, to assign to `identifier`.
    @discardableResult
    public func decodeJSONLDHeader<Attribute>(
        _ type: Any.Type
    ) throws -> String? where Key == JSONLDCodingKey<Attribute> {
        let expected = String(describing: type)
        if let found = try decodeIfPresent(String.self, forKey: .type), found != expected {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: self,
                debugDescription: "Expected @type '\(expected)' but found '\(found)'"
            )
        }
        return try decodeIfPresent(String.self, forKey: .id)
    }
}

// MARK: - Lenient decoding helpers

extension KeyedDecodingContainer {
    /// Decodes a `[String]` field leniently: accepts an array of strings OR a
    /// single string (wrapped into a one-element array). schema.org allows
    /// both forms for most repeatable properties (`url`, `email`, `sameAs`, …),
    /// and wild-web JSON-LD uses them interchangeably. Returns nil when the
    /// key is absent or holds neither form.
    public func decodeFlexibleStringList(forKey key: Key) -> [String]? {
        if let list = try? decodeIfPresent([String].self, forKey: key) { return list }
        if let single = try? decodeIfPresent(String.self, forKey: key) { return [single] }
        return nil
    }

    /// Decodes an `[Int]` field leniently: accepts an array of integers, a single
    /// integer, or either of those written as strings. schema.org's numeric
    /// repeatable properties (`byMonth`, `byMonthDay`, …) appear in all four forms
    /// in wild JSON-LD. Returns nil when the key is absent or holds none of them.
    public func decodeFlexibleIntList(forKey key: Key) -> [Int]? {
        if let list = try? decodeIfPresent([Int].self, forKey: key) { return list }
        if let single = try? decodeIfPresent(Int.self, forKey: key) { return [single] }
        if let strings = try? decodeIfPresent([String].self, forKey: key) {
            let ints = strings.compactMap(Int.init)
            return ints.count == strings.count ? ints : nil
        }
        if let string = try? decodeIfPresent(String.self, forKey: key), let n = Int(string) {
            return [n]
        }
        return nil
    }

    /// Decodes a schema.org Text field leniently: accepts a string, or a bare
    /// integer/number and stringifies it. YAML/JSON coerce unquoted numeric
    /// values (e.g. a `postalCode: 94016`) to numbers, which would otherwise
    /// fail a strict `String` decode. Returns nil when the key is absent.
    public func decodeStringLeniently(forKey key: Key) throws -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) { return string }
        if let int = try? decodeIfPresent(Int.self, forKey: key) { return String(int) }
        if let double = try? decodeIfPresent(Double.self, forKey: key) { return String(double) }
        return nil
    }
}
