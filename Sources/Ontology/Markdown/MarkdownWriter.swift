import Foundation
import Universal

private let frontmatterKeyPriority = ["taxon", "id"]

extension MarkdownDocument {
    /// Create a MarkdownDocument from any Entity, ready to write to disk.
    ///
    /// YAML frontmatter is the entity's own JSON encoding plus a `taxon` key.
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
    /// Transform an encoded entity into a frontmatter-ready JSON object: stamps
    /// `taxon` (at top level only), drops nulls, and recurses into nested
    /// objects. Hub types encode plain field names, so there is no JSON-LD
    /// framing left to strip here — see `JSONLD` for the framing direction.
    static func frontmatterObject(from json: JSON, taxon: Taxon) -> JSON {
        guard var obj = json.object else { return json }
        if !taxon.description.isEmpty {
            obj["taxon"] = .string(taxon.description)
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
