import Foundation
import Universal

/// Decodes YAML frontmatter strings into `Decodable` types.
///
/// Pipeline: YAML string → `YAML.parse` → `.json()` → `Decodable.init(json:)`
/// Uses the `universal` library for spec-compliant YAML parsing.
public struct FrontmatterParser {
    private init() {}

    /// Decode a YAML string into the given `Decodable` type.
    ///
    /// Frontmatter normalisation applied before decoding:
    /// - `taxon: …` is validated against the target type, then dropped (it is
    ///   consumed by holarchy machinery, not a struct field).
    /// - Legacy JSON-LD framing keys (`@id`, `@type`, `@context`) are folded
    ///   away so files written before the framing moved to the boundary still
    ///   read: `@id` becomes `id`, the other two are dropped.
    public static func decode<T: Decodable>(
        _ type: T.Type,
        from yaml: String,
        using decoder: JSONDecoder = .init()
    ) throws -> T {
        guard !yaml.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Empty frontmatter"))
        }
        let yamlValue = try YAML.parse(yaml: yaml)
        let json = try yamlValue.json()
        try validateTaxon(of: json, against: type)
        return try T(json: normalized(json))
    }

    /// `taxon` is the hub's own type tag, and frontmatter is the only format
    /// that carries one. Checking it here is what keeps a `person.md` from
    /// silently decoding as a `Place` whose fields happen to overlap — the
    /// role `@type` validation used to play inside each type's decoder.
    private static func validateTaxon<T>(of json: JSON, against type: T.Type) throws {
        guard let found = json.object?["taxon"]?.string,
              let entityType = T.self as? any SchemaEntityReference.Type
        else { return }
        let expected = entityType.taxon.description
        guard found == expected else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Expected taxon '\(expected)' but found '\(found)'"
            ))
        }
    }

    private static func normalized(_ json: JSON) -> JSON {
        guard var obj = json.object else { return json }
        obj.removeValue(forKey: "taxon")
        obj.removeValue(forKey: "@context")
        obj.removeValue(forKey: "@type")
        if let id = obj["@id"] {
            obj.removeValue(forKey: "@id")
            if obj["id"] == nil { obj["id"] = id }
        }
        return .object(obj.mapValues { $0.object == nil ? $0 : normalized($0) })
    }
}
