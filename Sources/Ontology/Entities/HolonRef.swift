import Foundation

/// A reference to another Holon — by identity (stable across renames) or by file path (for assets).
public enum HolonRef: Hashable, Sendable {
    /// Reference to a semantic entity by taxon + id. Survives directory reorganization.
    /// Rendered as `[[taxon.id]]` in markdown, e.g. `[[person.3f8a91b2]]`.
    case entity(Taxon, String)

    /// Reference to a file asset by relative path. Used for images, PDFs, maps, etc.
    /// Relative to the referencing document's location.
    case path(String)
}

public extension HolonRef {
    /// Convenience: construct an entity ref from a typed Holon.
    init(_ holon: some Holon) {
        self = .entity(holon.taxon, holon.id)
    }

    /// The wikilink-style string representation: `[[taxon.id]]` or `[[./path]]`.
    var wikilink: String {
        switch self {
        case .entity(let taxon, let id): "[[\(taxon).\(id)]]"
        case .path(let p):              "[[\(p)]]"
        }
    }

    /// Parses a wikilink into a `HolonRef`. Accepts either the bracketed
    /// form (`"[[person.3f8a91b2]]"`, as produced by `wikilink`) or just
    /// the body between the brackets (`"person.3f8a91b2"`, as
    /// `WikiLinkScanner` passes it after regex-extracting the capture
    /// group). Shared by `WikiLinkScanner` (scanning markdown bodies) and
    /// any store that persists `wikilink` strings and needs to parse them
    /// back (e.g. WAIS's `frame_features.value` column).
    init?(wikilink content: String) {
        var trimmed = content.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") {
            trimmed = String(trimmed.dropFirst(2).dropLast(2))
        }
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("./") || trimmed.hasPrefix("../") || trimmed.hasPrefix("/") {
            self = .path(trimmed)
            return
        }

        let parts = trimmed.split(separator: ".", maxSplits: 1)
        if parts.count == 2 {
            self = .entity(Taxon(String(parts[0])), String(parts[1]))
            return
        }

        self = .path(trimmed)
    }
}

extension HolonRef: CustomStringConvertible {
    public var description: String { wikilink }
}

/// Encodes/decodes as the `[[taxon.id]]` wikilink string (not Swift's
/// default synthesized enum representation, which would produce an opaque
/// `{"entity":{"_0":"person","_1":"jason"}}` object). This is what makes
/// hand-authored OKF frontmatter like `owner: "[[person.gm01]]"` -- the
/// format documented in this package's own README -- actually decode.
extension HolonRef: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let ref = HolonRef(wikilink: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid HolonRef wikilink: \(string)"
            )
        }
        self = ref
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wikilink)
    }
}
