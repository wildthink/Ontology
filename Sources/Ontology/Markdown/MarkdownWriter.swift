import Foundation
import Universal

private let frontmatterKeyPriority = ["taxon", "id"]

extension MarkdownDocument {
    /// Create a MarkdownDocument from any Entity, ready to write to disk.
    ///
    /// YAML frontmatter is derived from the entity's JSON-LD encoding with key
    /// normalisation: `@context` removed, `@type` → `taxon`, `@id` → `id`.
    /// Null and empty optional fields are omitted.
    public init<T: Entity & Encodable>(_ entity: T, body: String = "") throws {
        let data = try JSONEncoder().encode(entity)
        let json = try JSON.parse(data)
        let fm = Self.frontmatterObject(from: json, taxon: entity.taxon)
        self.frontmatter = YAMLSerializer.serialize(fm, keyPriority: frontmatterKeyPriority)
        self.body = body
    }

    /// The complete markdown string: YAML frontmatter fence followed by body.
    public func string() -> String {
        guard !frontmatter.isEmpty else { return body }
        let bodyPart = body.isEmpty ? "" : "\n\n\(body)"
        return "---\n\(frontmatter)\n---\(bodyPart)"
    }

    /// Write the document to a file URL, atomically.
    public func write(to url: URL) throws {
        try string().write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Key transformation (JSON-LD → native frontmatter)

private extension MarkdownDocument {
    /// Transform a JSON-LD encoded object into a frontmatter-ready JSON object:
    /// removes `@context`, renames `@type` → `taxon` (at top level only),
    /// renames `@id` → `id`, drops nulls, and recurses into nested objects.
    static func frontmatterObject(from json: JSON, taxon: Taxon) -> JSON {
        guard var obj = json.object else { return json }
        obj.removeValue(forKey: "@context")
        obj.removeValue(forKey: "@type")
        if !taxon.description.isEmpty {
            obj["taxon"] = .string(taxon.description)
        }
        if let id = obj["@id"] {
            obj.removeValue(forKey: "@id")
            obj["id"] = id
        }
        let cleaned = obj.compactMapValues { value -> JSON? in
            guard !value.isNull else { return nil }
            if value.object != nil {
                let nested = frontmatterObject(from: value, taxon: Taxon(""))
                guard !(nested.object?.isEmpty ?? true) else { return nil }
                return nested
            }
            return value
        }
        return .object(cleaned)
    }
}
