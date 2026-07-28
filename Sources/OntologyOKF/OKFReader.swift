import Foundation
import Ontology
import Universal

/// Decodes OKF v0.1 markdown documents into hub `Entity` types.
///
/// Key mapping (OKF → hub):
/// - `type`      → dropped (used externally to select target type)
/// - `id`        → `@id`
/// - `title`     → `name` (always wins over a stale `name` extension key)
/// - `resource`  → `url` (always wins over a stale `url` extension key)
/// - `timestamp` → written back into whichever `okfDateFields` entry supplied
///   it (always wins over that field's stale value), then dropped
/// - All other keys pass through to the hub type's decoder.
///
/// The OKF-native fields (`title`, `resource`, `timestamp`) are always treated
/// as authoritative over their hub-side echoes, since they're what a human or
/// tool editing the file at rest would actually change.
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

        // `id` is the hub's own key — it passes through untouched.

        // title is the OKF at-rest canonical field — it wins over a stale `name`
        // extension key (e.g. if a file was hand-edited after being written).
        if let title = obj["title"] {
            obj["name"] = title
        }
        obj.removeValue(forKey: "title")

        // resource is the OKF at-rest canonical field — it wins over a stale
        // `url` extension key.
        if let resource = obj["resource"] {
            obj["url"] = resource
        }
        obj.removeValue(forKey: "resource")

        // timestamp is the OKF at-rest canonical field — it wins over whichever
        // underlying hub date field originally derived it (first match in
        // okfDateFields, mirroring the precedence OKFDocument uses to derive it).
        if let timestamp = obj["timestamp"] {
            if let field = okfDateFields.first(where: { obj[$0] != nil }) {
                obj[field] = timestamp
            }
        }
        obj.removeValue(forKey: "timestamp")

        // taxon — drop (FrontmatterParser already strips this, but be explicit)
        obj.removeValue(forKey: "taxon")

        // Recurse into nested objects only — NOT into arrays. Array elements
        // (e.g. `Outline.nodes` / `OutlineNode.children`) are nested value
        // types with their own field named `title`, and running the title/
        // resource/timestamp remapping above on them would corrupt those
        // fields. `OKFDocument`'s write-side equivalent does recurse into
        // arrays (it only needs to strip `@type`/`@id`, not remap fields), so
        // don't "fix" this asymmetry without re-checking that reasoning.
        return .object(obj.mapValues { value -> JSON in
            guard value.object != nil else { return value }
            return normalized(value)
        })
    }
}
