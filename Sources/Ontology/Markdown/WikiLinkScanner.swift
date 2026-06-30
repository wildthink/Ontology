import Foundation

/// Scans markdown text for `[[...]]` wikilinks and converts them to `HolonRef` values.
///
/// - Entity links: `[[person.3f8a91b2]]` → `.entity(Taxon("person"), "3f8a91b2")`
/// - Path links:   `[[./assets/portrait.jpg]]` → `.path("./assets/portrait.jpg")`
public struct WikiLinkScanner {
    private init() {}

    private static let regex: NSRegularExpression = {
        // Match [[...]] where content does not contain ] or [
        try! NSRegularExpression(pattern: #"\[\[([^\[\]]+)\]\]"#)
    }()

    /// Return all `HolonRef` values found in `text`, in order of appearance.
    public static func scan(_ text: String) -> [HolonRef] {
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return ref(from: String(text[range]).trimmingCharacters(in: .whitespaces))
        }
    }

    private static func ref(from content: String) -> HolonRef? {
        guard !content.isEmpty else { return nil }

        if content.hasPrefix("./") || content.hasPrefix("../") || content.hasPrefix("/") {
            return .path(content)
        }

        // taxon.id — the dot separates taxon from the rest of the id
        let parts = content.split(separator: ".", maxSplits: 1)
        if parts.count == 2 {
            let taxon = Taxon(String(parts[0]))
            let id = String(parts[1])
            return .entity(taxon, id)
        }

        // Unrecognised format — treat as path reference
        return .path(content)
    }
}
