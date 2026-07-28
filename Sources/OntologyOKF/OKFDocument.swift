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
/// - Swift type name → `type` (required)
/// - `name`   → `title` (recommended); for `Person`, derived from givenName + familyName
/// - `url`    → `resource`
/// - `id` is already the hub's own key and passes through unchanged
/// - First available date field → `timestamp`
/// - All other fields preserved as OKF extension keys.
public struct OKFDocument {
    public let frontmatter: String
    public let body: String

    public init<T: Entity & Encodable>(_ entity: T, body: String = "") throws {
        let data = try JSONEncoder().encode(entity)
        let json = try JSON.parse(data)
        let fm = Self.okfObject(from: json, type: String(describing: T.self))
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

// MARK: - hub → OKF key transformation

private extension OKFDocument {
    /// - Parameter type: the OKF `type` field, supplied by the caller from the
    ///   Swift type name. Only the top-level object gets one; nested values are
    ///   transformed with `type: nil`.
    static func okfObject(from json: JSON, type: String?) -> JSON {
        guard var obj = json.object else { return json }

        if let type { obj["type"] = .string(type) }

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
    /// so nested entities (e.g. `OutlineNode` inside `Outline.nodes`) get the
    /// same `name` → `title` treatment. `type` is document-level, so nested
    /// objects do not receive one.
    static func okfValue(_ value: JSON) -> JSON {
        if value.object != nil { return okfObject(from: value, type: nil) }
        if let arr = value.array {
            return .array(arr.compactMap { $0.isNull ? nil : okfValue($0) })
        }
        return value
    }
}
