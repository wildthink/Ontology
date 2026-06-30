import Foundation
import Ontology
import Universal

/// Decodes OKF v0.1 markdown documents into hub `Entity` types.
///
/// Key mapping (OKF → hub):
/// - `type`     → dropped (used externally to select target type)
/// - `id`       → `@id`
/// - `title`    → `name` (if `name` not already present)
/// - `resource` → `url`  (if `url` not already present)
/// - `timestamp` → dropped
/// - All other keys pass through to the hub type's decoder.
public enum OKFReader {

    /// Decode an OKF document string into a hub entity type.
    public static func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        let doc = MarkdownDocument(string: string)
        return try decode(type, fromFrontmatter: doc.frontmatter)
    }

    /// Decode an OKF markdown file into a hub entity type.
    public static func decode<T: Decodable>(_ type: T.Type, contentsOf url: URL) throws -> T {
        let doc = try MarkdownDocument(contentsOf: url)
        return try decode(type, fromFrontmatter: doc.frontmatter)
    }

    // MARK: - Internal

    static func decode<T: Decodable>(_ type: T.Type, fromFrontmatter yaml: String) throws -> T {
        let yamlValue = try YAML.parse(yaml: yaml)
        var json = try yamlValue.json()
        json = normalized(json)
        return try T(json: json)
    }

    /// Normalise OKF keys to hub-type keys before decoding.
    static func normalized(_ json: JSON) -> JSON {
        guard var obj = json.object else { return json }

        // type — OKF concept kind; hub decoders don't use it (validation is optional)
        obj.removeValue(forKey: "type")

        // id → @id
        if let id = obj["id"] {
            obj["@id"] = id
            obj.removeValue(forKey: "id")
        }

        // title → name (only if name is absent; keeps extension fields intact)
        if obj["name"] == nil, let title = obj["title"] {
            obj["name"] = title
        }
        obj.removeValue(forKey: "title")

        // resource → url (only if url is absent)
        if obj["url"] == nil, let resource = obj["resource"] {
            obj["url"] = resource
        }
        obj.removeValue(forKey: "resource")

        // timestamp — no generic timestamp field on hub types; drop it
        obj.removeValue(forKey: "timestamp")

        // taxon — drop (FrontmatterParser already strips this, but be explicit)
        obj.removeValue(forKey: "taxon")

        // Recurse into nested objects
        return .object(obj.mapValues { value -> JSON in
            guard value.object != nil else { return value }
            return normalized(value)
        })
    }
}
