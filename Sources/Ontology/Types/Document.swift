import Foundation

/// A reference to a file, application, or web resource discovered by search —
/// a Spotlight hit, an iCloud document, an application bundle, or a web page
/// with no better-fitting hub type.
///
/// `Document` is the flexible catch-all for "a thing at a URL with open
/// metadata". Typed fields cover the universally useful properties; everything
/// else (Spotlight `kMDItem*` values, OpenGraph tags, raw JSON-LD) rides in
/// `meta`. Distinct from `Media` (an illustrative asset with caption/credit)
/// and `Artifact` (an in-fiction object).
///
/// ```markdown
/// ---
/// taxon: document
/// id: document.9a2f11c4
/// name: Session Notes.pdf
/// url: file:///Users/jane/Notes/Session%20Notes.pdf
/// contentType: com.adobe.pdf
/// meta:
///   kMDItemPageCount: 12
/// ---
/// ```
public struct Document: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    /// Location of the resource — file URL, iCloud URL, or web URL.
    public var url: URL?
    /// UTI (e.g. `com.adobe.pdf`) or MIME type (e.g. `text/html`).
    public var contentType: String?
    public var dateCreated: DateTime?
    public var dateModified: DateTime?
    /// Size in bytes, when known.
    public var size: Int?
    public var handles: [Handle]?
    /// Open, schema-free metadata (see `Meta`).
    public var meta: Meta?

    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        url: URL? = nil,
        contentType: String? = nil,
        dateCreated: DateTime? = nil,
        dateModified: DateTime? = nil,
        size: Int? = nil,
        handles: [Handle]? = nil,
        meta: Meta? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.url = url
        self.contentType = contentType
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.size = size
        self.handles = handles
        self.meta = meta
    }
}

extension Document: Codable {
    private enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case name, description, url, contentType
        case dateCreated, dateModified, size, handles, meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.value(.identifier)
        name = try container.value(.name)
        description = try container.value(.description)
        url = try container.lenientURL(.url)
        contentType = try container.value(.contentType)
        dateCreated = try container.value(.dateCreated)
        dateModified = try container.value(.dateModified)
        size = try container.value(.size)
        handles = try container.value(.handles)
        meta = try container.value(.meta)
    }
}
