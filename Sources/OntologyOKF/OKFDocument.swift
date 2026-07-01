import Foundation
import Ontology
import Universal

/// OKF key order: required first, then recommended, then extensions.
private let okfKeyPriority = ["type", "title", "description", "resource", "tags", "timestamp", "id"]

/// Hub date fields that back the OKF `timestamp` field, in precedence order.
/// Shared by `OKFDocument` (write: pick the first present field) and `OKFReader`
/// (read: write an edited `timestamp` back into whichever field supplied it).
let okfDateFields = ["startDate", "endDate", "dueDate", "recordedAt", "scheduledTime"]

/// An OKF v0.1-compliant markdown document produced from a hub `Entity`.
///
/// Key mapping (hub → OKF):
/// - `@type`  → `type`  (required)
/// - `name`   → `title` (recommended); for `Person`, derived from givenName + familyName
/// - `url`    → `resource`
/// - `@id`    → `id`    (extension field; OKF must preserve unknown keys)
/// - `@context` removed
/// - First available date field → `timestamp`
/// - All other fields preserved as OKF extension keys.
public struct OKFDocument {
    public let frontmatter: String
    public let body: String

    public init<T: Entity & Encodable>(_ entity: T, body: String = "") throws {
        let data = try JSONEncoder().encode(entity)
        let json = try JSON.parse(data)
        let fm = Self.okfObject(from: json)
        self.frontmatter = YAMLSerializer.serialize(fm, keyPriority: okfKeyPriority)
        self.body = body
    }

    /// The complete OKF markdown string (YAML frontmatter fence + body).
    public func string() -> String {
        let bodyPart = body.isEmpty ? "" : "\n\n\(body)"
        return "---\n\(frontmatter)\n---\(bodyPart)"
    }

    /// Write to a file URL, atomically.
    public func write(to url: URL) throws {
        try string().write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - JSON-LD → OKF key transformation

private extension OKFDocument {
    static func okfObject(from json: JSON) -> JSON {
        guard var obj = json.object else { return json }

        // @context — drop
        obj.removeValue(forKey: "@context")

        // @type → type
        if let typeVal = obj["@type"] {
            obj["type"] = typeVal
            obj.removeValue(forKey: "@type")
        }

        // @id → id
        if let id = obj["@id"] {
            obj["id"] = id
            obj.removeValue(forKey: "@id")
        }

        // name → title; keep name as extension for round-trip
        if let name = obj["name"] {
            obj["title"] = name
        }

        // Person has no `name` — derive title from givenName + familyName
        if obj["title"] == nil {
            let given  = obj["givenName"]?.string  ?? ""
            let family = obj["familyName"]?.string ?? ""
            let full = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            if !full.isEmpty { obj["title"] = .string(full) }
        }

        // url (string) → resource; keep url as extension for round-trip
        if let url = obj["url"] {
            obj["resource"] = url
        }

        // timestamp — first available date field
        if obj["timestamp"] == nil {
            for field in okfDateFields {
                if let d = obj[field], !d.isNull {
                    obj["timestamp"] = d
                    break
                }
            }
        }

        // Recursively process nested objects and arrays (e.g. Outline.nodes); drop nulls
        let cleaned = obj.compactMapValues { value -> JSON? in
            guard !value.isNull else { return nil }
            return okfValue(value)
        }
        return .object(cleaned)
    }

    /// Applies `okfObject` transformation through objects and arrays of objects,
    /// so nested entities (e.g. `OutlineNode` inside `Outline.nodes`) also get
    /// their `@type`/`@id` stripped instead of leaking raw JSON-LD keys into YAML.
    static func okfValue(_ value: JSON) -> JSON {
        if value.object != nil { return okfObject(from: value) }
        if let arr = value.array {
            return .array(arr.compactMap { $0.isNull ? nil : okfValue($0) })
        }
        return value
    }
}
