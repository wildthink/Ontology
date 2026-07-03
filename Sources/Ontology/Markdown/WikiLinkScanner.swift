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
            return HolonRef(wikilink: String(text[range]))
        }
    }
}
