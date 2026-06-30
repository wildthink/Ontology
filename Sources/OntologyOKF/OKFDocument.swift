import Foundation
import Ontology
import Universal

/// OKF key order: required first, then recommended, then extensions.
private let okfKeyPriority = ["type", "title", "description", "resource", "tags", "timestamp", "id"]

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
        let dateFields = ["startDate", "endDate", "recordedAt", "scheduledTime"]
        if obj["timestamp"] == nil {
            for field in dateFields {
                if let d = obj[field], !d.isNull {
                    obj["timestamp"] = d
                    break
                }
            }
        }

        // Recursively process nested objects; drop nulls
        let cleaned = obj.compactMapValues { value -> JSON? in
            guard !value.isNull else { return nil }
            if value.object != nil { return okfObject(from: value) }
            return value
        }
        return .object(cleaned)
    }
}
