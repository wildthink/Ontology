import Foundation
import Universal

// MARK: - Framing at the boundary

/// Hub types encode as plain JSON — field names, `id`, no `@`-prefixed keys.
/// JSON-LD framing is applied here, at the boundary, only when a schema.org
/// record is what's wanted.
///
/// This is the write direction. The read direction is `SchemaTypeRegistry`,
/// which routes a wild-web `@type` onto the best-fitting hub type; nothing
/// else in the package needs to understand JSON-LD.
public enum JSONLD {

    /// Frame a hub entity as a schema.org JSON-LD object: adds `@context` and
    /// `@type`, and renames `id` to `@id`.
    public static func object(_ entity: some Entity, context: String = schema.org.rawValue) throws -> JSON {
        let json = try JSON.parse(JSONEncoder().encode(entity))
        return framed(json, type: String(describing: type(of: entity)), context: context)
    }

    /// Frame a hub entity as serialised JSON-LD.
    public static func data(_ entity: some Entity, context: String = schema.org.rawValue) throws -> Data {
        Data(try object(entity, context: context).canonicalJSON.utf8)
    }

    /// schema.org type names for the nested value objects the hub embeds.
    /// Nested objects have no Swift type available at the JSON level, so the
    /// field name supplies it. Anything not listed is emitted untyped, which
    /// is valid JSON-LD.
    private static let nestedTypeNames: [String: String] = [
        "geo": "GeoCoordinates",
        "address": "PostalAddress",
        "place": "Place",
        "location": "Place",
        "organizer": "Person",
        "effort": "QuantitativeValue",
        "contactPoint": "ContactPoint",
    ]

    private static func framed(_ json: JSON, type: String?, context: String?) -> JSON {
        guard var obj = json.object else { return json }
        if let context { obj["@context"] = .string(context) }
        if let type { obj["@type"] = .string(type) }
        if let id = obj["id"] {
            obj.removeValue(forKey: "id")
            obj["@id"] = id
        }
        for (key, value) in obj where value.object != nil || value.array != nil {
            // `meta` is an opaque bag — its contents are not schema.org terms.
            guard key != "meta" else { continue }
            let nestedType = nestedTypeNames[key]
            if let array = value.array {
                obj[key] = .array(array.map { framed($0, type: nestedType, context: nil) })
            } else {
                obj[key] = framed(value, type: nestedType, context: nil)
            }
        }
        return .object(obj)
    }
}

// MARK: - Decoding helpers

extension KeyedDecodingContainer {
    /// An optional field: an absent key decodes to nil.
    ///
    /// Shorthand for `decodeIfPresent`, which every optional hub field needs —
    /// frontmatter and wild-web records both omit far more than they carry.
    public func value<T: Decodable>(_ key: Key) throws -> T? {
        try decodeIfPresent(T.self, forKey: key)
    }

    /// A field with a default: an absent key decodes to `fallback`.
    public func value<T: Decodable>(_ key: Key, or fallback: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? fallback
    }

    /// A URL field: a string `URL(string:)` rejects decodes to nil rather than
    /// failing the whole record. Decoding `URL` directly would throw, and a
    /// junk `url` is not a reason to lose an otherwise good wild-web record.
    public func lenientURL(_ key: Key) throws -> URL? {
        guard let string = try decodeIfPresent(String.self, forKey: key) else { return nil }
        return URL(string: string)
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
