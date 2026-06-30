import Foundation

/// A markdown file split into YAML frontmatter and markdown body.
///
/// Files are expected to open with a `---` fence, contain YAML key-value
/// fields, close with a second `---`, and then have free-form markdown.
///
/// ```markdown
/// ---
/// taxon: person
/// id: person.3f8a91b2
/// givenName: Jane
/// ---
///
/// Jane has run The Rusty Flagon for thirty years.
/// ```
public struct MarkdownDocument: Sendable {
    /// Raw YAML string extracted from between the `---` fences.
    public let frontmatter: String
    /// Markdown content that follows the closing `---` fence.
    public let body: String

    public init(string content: String) {
        guard content.hasPrefix("---") else {
            self.frontmatter = ""
            self.body = content
            return
        }

        let lines = content.components(separatedBy: "\n")
        var closingIndex: Int? = nil
        for (i, line) in lines.enumerated().dropFirst() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                closingIndex = i
                break
            }
        }

        guard let end = closingIndex else {
            self.frontmatter = ""
            self.body = content
            return
        }

        self.frontmatter = lines[1..<end].joined(separator: "\n")
        self.body = lines[(end + 1)...].joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
    }

    public init(contentsOf url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        self.init(string: content)
    }
}

extension MarkdownDocument {
    /// Decode the frontmatter into an Entity type using the YAML → JSON → Decodable pipeline.
    public func decode<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder = .init()) throws -> T {
        try FrontmatterParser.decode(type, from: frontmatter, using: decoder)
    }

    /// All wikilinks (`[[...]]`) found in the body, as `HolonRef` values.
    public var wikilinks: [HolonRef] {
        WikiLinkScanner.scan(body)
    }
}
