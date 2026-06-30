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
    /// - `id: …` is renamed to `@id: …` so it maps to the JSON-LD `@id` field.
    /// - `taxon: …` is dropped (it is consumed by holarchy machinery, not a struct field).
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
        var json = try yamlValue.json()
        json = normalized(json)
        return try T(json: json)
    }

    private static func normalized(_ json: JSON) -> JSON {
        guard var obj = json.object else { return json }
        if let id = obj["id"] {
            obj["@id"] = id
            obj.removeValue(forKey: "id")
        }
        obj.removeValue(forKey: "taxon")
        return .object(obj)
    }
}
