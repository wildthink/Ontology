import Foundation
import Universal

extension MarkdownDocument {
    /// Create a MarkdownDocument from any Entity, ready to write to disk.
    ///
    /// The YAML frontmatter is derived from the entity's JSON-LD encoding with
    /// key normalisation: `@context` removed, `@type` → `taxon` (lowercase),
    /// `@id` → `id`. Null / empty optional fields are omitted.
    public init<T: Entity & Encodable>(_ entity: T, body: String = "") throws {
        let data = try JSONEncoder().encode(entity)
        let json = try JSON.parse(data)
        let fm = Self.frontmatterObject(from: json, taxon: entity.taxon)
        self.frontmatter = Self.yaml(from: fm, indent: 0)
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

// MARK: - Internal serialisation helpers

private extension MarkdownDocument {
    /// Transform a JSON-LD object into a frontmatter-ready JSON object.
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
        // Drop nulls; recursively normalise nested objects (no taxon injection).
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

    // MARK: YAML emitter

    /// Emit a JSON value as a YAML string at the given indent level.
    /// Top-level objects are emitted as bare key: value pairs (no leading indent).
    static func yaml(from json: JSON, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)

        if let s = json.string {
            return yamlScalar(s)
        }
        if let n = json.number {
            return n.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(n))" : "\(n)"
        }
        if let b = json.boolean {
            return b ? "true" : "false"
        }
        if json.isNull {
            return "null"
        }
        if let arr = json.array {
            return yamlArray(arr, pad: pad, indent: indent)
        }
        if let obj = json.object {
            return yamlObject(obj, pad: pad, indent: indent)
        }
        return ""
    }

    static func yamlArray(_ arr: [JSON], pad: String, indent: Int) -> String {
        guard !arr.isEmpty else { return "[]" }
        let allScalar = arr.allSatisfy { $0.object == nil && $0.array == nil }
        if allScalar {
            let items = arr.map { yaml(from: $0, indent: 0) }.joined(separator: ", ")
            return "[\(items)]"
        }
        let lines = arr.map { "\(pad)- \(yaml(from: $0, indent: indent + 1))" }
        return "\n" + lines.joined(separator: "\n")
    }

    static func yamlObject(_ obj: [String: JSON], pad: String, indent: Int) -> String {
        guard !obj.isEmpty else { return "{}" }
        // Canonical key order: taxon, id first; then alphabetical.
        let priority = ["taxon", "id"]
        let sorted = priority.filter { obj[$0] != nil }
            + obj.keys.filter { !priority.contains($0) }.sorted()
        var lines: [String] = []
        for key in sorted {
            guard let value = obj[key], !value.isNull else { continue }
            if value.object != nil || (value.array?.first?.object != nil) {
                let nested = yaml(from: value, indent: indent + 1)
                if value.object != nil {
                    lines.append("\(pad)\(key):")
                    let nestedLines = nested.split(separator: "\n", omittingEmptySubsequences: false)
                        .map { "\(pad)  \($0)" }
                    lines.append(contentsOf: nestedLines)
                } else {
                    lines.append("\(pad)\(key): \(nested)")
                }
            } else {
                lines.append("\(pad)\(key): \(yaml(from: value, indent: indent))")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Quote a string if it contains characters that YAML would misinterpret.
    static func yamlScalar(_ s: String) -> String {
        let special = CharacterSet(charactersIn: ":#{}[]|>&*!,?\"'\\")
            .union(.newlines)
        let needsQuotes = s.isEmpty
            || s.unicodeScalars.contains(where: { special.contains($0) })
            || s.hasPrefix(" ") || s.hasSuffix(" ")
            || ["true", "false", "null", "~"].contains(s.lowercased())
            || Double(s) != nil || Int(s) != nil
        guard needsQuotes else { return s }
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
