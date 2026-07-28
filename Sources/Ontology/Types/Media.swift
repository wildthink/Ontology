import Foundation

/// A reference to an external or local image/video/audio resource, with its
/// own descriptive metadata (caption, credit, format).
///
/// `Media` is distinct from `Artifact`: `Media` is a real-world file — a
/// portrait, a battle map, a recorded session — that illustrates or documents
/// something, and is not itself an in-fiction object. Any entity (`Person`,
/// `Place`, `Artifact`, ...) can point at a `Media` via `HolonRef` to attach
/// an illustration without conflating "the thing" and "a picture of the thing".
///
/// For a same-repo asset with no metadata worth tracking, `HolonRef.path`
/// (e.g. `./assets/portrait.jpg`) is still the lighter-weight option — reach
/// for `Media` when the resource is external, or when caption/credit/format
/// need to be recorded and referenced from multiple places.
///
/// ```markdown
/// ---
/// taxon: media
/// id: media.evermore-map01
/// name: Map of Evermore
/// contentUrl: https://example.com/maps/evermore.png
/// encodingFormat: image/png
/// credit: Cartography by Jane Smith
/// ---
/// ```
public struct Media: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    /// The external (or local) resource this Media wraps.
    public var contentUrl: URL
    /// MIME type, e.g. "image/png", "video/mp4", "audio/mpeg".
    public var encodingFormat: String?
    /// Attribution / license text.
    public var credit: String?

    /// Open, schema-free metadata (see `Meta`).

    public var meta: Meta?


    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        contentUrl: URL,
        encodingFormat: String? = nil,
        credit: String? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.contentUrl = contentUrl
        self.encodingFormat = encodingFormat
        self.credit = credit
    }
}

extension Media: Codable {
    private enum CodingKeys: String, CodingKey {
        case meta
        case name, description, contentUrl, encodingFormat, credit
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        try container.encodeJSONLDHeader(Self.self, id: identifier, encoder: encoder)
        try container.encodeIfPresent(meta, forKey: .attribute(.meta))
        try container.encodeIfPresent(name, forKey: .attribute(.name))
        try container.encodeIfPresent(description, forKey: .attribute(.description))
        try container.encode(contentUrl, forKey: .attribute(.contentUrl))
        try container.encodeIfPresent(encodingFormat, forKey: .attribute(.encodingFormat))
        try container.encodeIfPresent(credit, forKey: .attribute(.credit))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        identifier = try container.decodeJSONLDHeader(Self.self)

        meta = try container.decodeIfPresent(Meta.self, forKey: .attribute(.meta))
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        contentUrl = try container.decode(URL.self, forKey: .attribute(.contentUrl))
        encodingFormat = try container.decodeIfPresent(String.self, forKey: .attribute(.encodingFormat))
        credit = try container.decodeIfPresent(String.self, forKey: .attribute(.credit))
    }
}
