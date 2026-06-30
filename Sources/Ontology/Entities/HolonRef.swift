import Foundation

/// A reference to another Holon — by identity (stable across renames) or by file path (for assets).
public enum HolonRef: Hashable, Codable, Sendable {
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
        case .entity(let taxon, let id): "[[  \(taxon).\(id)]]"
        case .path(let p):              "[[\(p)]]"
        }
    }
}

extension HolonRef: CustomStringConvertible {
    public var description: String { wikilink }
}
