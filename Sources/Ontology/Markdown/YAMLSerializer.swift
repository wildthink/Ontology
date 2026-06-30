import Foundation
import Universal

/// Serialises a `Universal.JSON` value to a YAML string.
///
/// Handles the subset of YAML needed for entity frontmatter:
/// flat and nested key-value mappings, scalar arrays, block arrays of objects.
public enum YAMLSerializer {

    /// Serialise a JSON value. Pass `keyPriority` to control ordering of object keys.
    public static func serialize(_ json: JSON, keyPriority: [String] = [], indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        if let s = json.string { return scalar(s) }
        if let n = json.number {
            return n.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(n))" : "\(n)"
        }
        if let b = json.boolean { return b ? "true" : "false" }
        if json.isNull { return "null" }
        if let arr = json.array { return array(arr, pad: pad, indent: indent) }
        if let obj = json.object { return object(obj, pad: pad, indent: indent, priority: keyPriority) }
        return ""
    }

    // MARK: - Internal helpers (internal so OntologyOKF can reuse via Universal import)

    static func array(_ arr: [JSON], pad: String, indent: Int) -> String {
        guard !arr.isEmpty else { return "[]" }
        let allScalar = arr.allSatisfy { $0.object == nil && $0.array == nil }
        if allScalar {
            return "[" + arr.map { serialize($0) }.joined(separator: ", ") + "]"
        }
        return "\n" + arr.map { "\(pad)- \(serialize($0, indent: indent + 1))" }.joined(separator: "\n")
    }

    static func object(_ obj: [String: JSON], pad: String, indent: Int, priority: [String]) -> String {
        guard !obj.isEmpty else { return "{}" }
        let sorted = priority.filter { obj[$0] != nil }
            + obj.keys.filter { !priority.contains($0) }.sorted()
        var lines: [String] = []
        for key in sorted {
            guard let value = obj[key], !value.isNull else { continue }
            if value.object != nil || (value.array?.first?.object != nil) {
                let nested = serialize(value, keyPriority: [], indent: indent + 1)
                if value.object != nil {
                    lines.append("\(pad)\(key):")
                    let nestedLines = nested
                        .split(separator: "\n", omittingEmptySubsequences: false)
                        .map { "\(pad)  \($0)" }
                    lines.append(contentsOf: nestedLines)
                } else {
                    lines.append("\(pad)\(key): \(nested)")
                }
            } else {
                lines.append("\(pad)\(key): \(serialize(value))")
            }
        }
        return lines.joined(separator: "\n")
    }

    static func scalar(_ s: String) -> String {
        let special = CharacterSet(charactersIn: ":#{}[]|>&*!,?\"'\\").union(.newlines)
        let needsQuotes = s.isEmpty
            || s.unicodeScalars.contains(where: { special.contains($0) })
            || s.hasPrefix(" ") || s.hasSuffix(" ")
            || ["true", "false", "null", "~"].contains(s.lowercased())
            || Double(s) != nil || Int(s) != nil
        guard needsQuotes else { return s }
        return "\""
            + s.replacingOccurrences(of: "\\", with: "\\\\")
               .replacingOccurrences(of: "\"", with: "\\\"")
               .replacingOccurrences(of: "\n", with: "\\n")
            + "\""
    }
}
