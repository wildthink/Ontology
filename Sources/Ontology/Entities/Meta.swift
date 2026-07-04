@_exported import Universal

/// Open, schema-free metadata carried by every `Entity`.
///
/// `meta` is the flexible side-channel for attributes that have no dedicated
/// field in the hub schema — Spotlight `kMDItem*` values, OpenGraph `og:*`
/// tags, raw JSON-LD records, provider-specific extras. Values are
/// `Universal.JSON`, so any YAML/JSON-representable structure round-trips
/// through markdown frontmatter under a nested `meta:` key without ever
/// colliding with schema field names.
///
/// ```markdown
/// ---
/// taxon: document
/// id: document.9a2f11c4
/// name: Session Notes.pdf
/// meta:
///   kMDItemPixelWidth: 1920
///   kMDItemAuthors:
///     - Jane Smith
/// ---
/// ```
public typealias Meta = [String: JSON]
