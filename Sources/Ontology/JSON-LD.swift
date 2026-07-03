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
}
