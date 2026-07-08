import Foundation
import Ontology
import Universal

/// A format-level OKF concept: the on-disk `.md` envelope (frontmatter + body).
///
/// This is the *persistence* representation shared across the OKF ecosystem —
/// distinct from the semantic hub entities (`Person`, `Place`, …), which a
/// concept decodes *into* via `OKFReader` when typed behavior is needed. The
/// catalog layer (`OKFCatalog`) moves these envelopes around; typed decoding is
/// a separate, on-demand concern (see `decode(_:)`).
///
/// `id` is the concept's **bundle-relative path** (e.g. `items/<uuid>.md`) — the
/// stable identifier the catalog index links to. It is NOT the frontmatter `id`
/// key (the hub `@id`), which is a semantic extension field.
///
/// Reading uses a real YAML parser (`Universal`) with a lenient line-based
/// fallback; writing is deterministic and matches the OKF spec's key order.
public struct OKFConcept: Identifiable, Hashable, Sendable {
    /// `type` value for a section concept — a structural outline node that owns a
    /// file (carrying its own icon/color/notes), linked from the index like a leaf.
    public static let sectionType = "Section"
    /// `type` value for an embedded note — content lives in `body`, no external `resource`.
    public static let noteType = "Note"

    /// Bundle-relative path, e.g. `items/abc123.md`. Stable across saves.
    public var id: String
    /// OKF `type` string (`Website`, `LocalFile`, `Section`, `Note`, or any Taxon).
    public var type: String
    public var title: String?
    /// Maps to frontmatter `description`.
    public var summary: String?
    /// The link target (`resource`).
    public var resource: URL?
    public var tags: [String]
    public var timestamp: Date?
    /// Optional SF Symbol override for display. Presentation decoration only.
    public var icon: String?
    /// Optional named palette color. Presentation decoration only.
    public var color: String?
    /// Bundle-lifecycle marker: when the concept was moved to trash. `nil` for live
    /// concepts. Drives save-time decay (see `OKFCatalog`).
    public var deletedAt: Date?
    /// Markdown body after the frontmatter.
    public var body: String
    /// Unknown frontmatter keys, preserved verbatim (spec §4.1). Carries a typed entity's
    /// structured fields — `address`, `geo`, `givenName`, the hub `id`, etc. — so they survive
    /// a round-trip and are visible to `decode(_:)`. Empty for plain link/note concepts.
    public var extras: [String: JSON]

    public var isSection: Bool { type == Self.sectionType }
    public var isNote: Bool { type == Self.noteType }

    /// Frontmatter keys OKFConcept models directly; everything else is preserved in `extras`.
    static let knownKeys: Set<String> = [
        "type", "title", "description", "resource", "tags", "timestamp", "icon", "color", "deleted",
    ]

    public init(
        id: String,
        type: String = "Website",
        title: String? = nil,
        summary: String? = nil,
        resource: URL? = nil,
        tags: [String] = [],
        timestamp: Date? = nil,
        icon: String? = nil,
        color: String? = nil,
        deletedAt: Date? = nil,
        body: String = "",
        extras: [String: JSON] = [:]
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.summary = summary
        self.resource = resource
        self.tags = tags
        self.timestamp = timestamp
        self.icon = icon
        self.color = color
        self.deletedAt = deletedAt
        self.body = body
        self.extras = extras
    }

    /// A convenience new-section concept with a stable UUID-based id.
    public init(sectionTitle: String) {
        self.init(
            id: "items/\(UUID().uuidString.lowercased()).md",
            type: Self.sectionType,
            title: sectionTitle,
            timestamp: Date()
        )
    }

    /// A convenience new concept from a URL, typed by scheme, with a stable id.
    public init(resource: URL) {
        self.init(
            id: "items/\(UUID().uuidString.lowercased()).md",
            type: resource.isFileURL ? "LocalFile" : "Website",
            resource: resource,
            timestamp: Date()
        )
    }

    /// The title shown in a flat listing when no explicit title is set.
    public var displayTitle: String { title ?? resource?.host() ?? id }
}

// MARK: - Markdown serialization

public extension OKFConcept {
    /// Parse an OKF concept from a `.md` file's text. Requires a leading `---` fence.
    init?(id: String, markdown text: String) {
        guard text.hasPrefix("---") else { return nil }
        let doc = MarkdownDocument(string: text)
        // A concept file must actually close its frontmatter fence; `MarkdownDocument`
        // returns empty frontmatter + full body when it can't find the closer.
        guard !doc.frontmatter.isEmpty else { return nil }

        let fm = OKFConcept.frontmatterObject(doc.frontmatter)
        self.init(
            id: id,
            type: fm["type"]?.string ?? "Website",
            title: OKFConcept.nonEmpty(fm["title"]?.string),
            summary: OKFConcept.nonEmpty(fm["description"]?.string),
            resource: (fm["resource"]?.string).flatMap { URL(string: $0) },
            tags: OKFConcept.parseTags(fm["tags"]),
            timestamp: (fm["timestamp"]?.string).flatMap(OKFConcept.parseDate),
            icon: OKFConcept.nonEmpty(fm["icon"]?.string),
            color: OKFConcept.nonEmpty(fm["color"]?.string),
            deletedAt: (fm["deleted"]?.string).flatMap(OKFConcept.parseDate),
            body: doc.body.trimmingCharacters(in: .whitespacesAndNewlines),
            extras: fm.filter { !OKFConcept.knownKeys.contains($0.key) }
        )
    }

    /// Serialize to deterministic OKF markdown (spec key order: required, recommended, extensions).
    func markdownString() -> String {
        var lines = ["---", "type: \(type)"]
        if let title, !title.isEmpty { lines.append("title: \(title)") }
        if let summary, !summary.isEmpty { lines.append("description: \(summary)") }
        if let resource { lines.append("resource: \(resource.absoluteString)") }
        if !tags.isEmpty { lines.append("tags: [\(tags.joined(separator: ", "))]") }
        if let timestamp { lines.append("timestamp: \(OKFConcept.isoString(timestamp))") }
        if let icon, !icon.isEmpty { lines.append("icon: \(icon)") }
        if let color, !color.isEmpty { lines.append("color: \(color)") }
        if let deletedAt { lines.append("deleted: \(OKFConcept.isoString(deletedAt))") }
        // Preserved extension keys (a typed entity's structured fields), deterministically ordered.
        if !extras.isEmpty {
            let yaml = YAMLSerializer.serialize(.object(extras))
            lines += yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        }
        lines.append("---")
        if !body.isEmpty { lines += ["", body] }
        return lines.joined(separator: "\n")
    }

    /// Decode this concept's frontmatter+body into a semantic hub entity via `OKFReader`.
    /// Use when typed behavior (a `Person`, `Place`, …) is needed rather than the envelope.
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try OKFReader.decode(type, from: markdownString())
    }

    /// Build a concept envelope from a semantic hub entity. The entity's `@type` becomes the
    /// concept `type`, `name`→`title`, `url`→`resource`, and all other fields land in `extras`,
    /// so `decode(_:)` recovers the same entity.
    init<T: Entity & Encodable>(id: String, entity: T, body: String = "") throws {
        let text = try OKFDocument(entity, body: body).string()
        guard let parsed = OKFConcept(id: id, markdown: text) else {
            throw OKFConceptError.malformed(id)
        }
        self = parsed
    }
}

public enum OKFConceptError: Error, Sendable {
    case malformed(String)
}

// MARK: - Frontmatter parsing helpers

private extension OKFConcept {
    /// Parse frontmatter YAML into a key→JSON map. Uses `Universal`'s YAML parser,
    /// falling back to a lenient line parser when the strict parser rejects the input
    /// (e.g. an unquoted scalar containing a colon).
    static func frontmatterObject(_ yaml: String) -> [String: JSON] {
        if let json = try? YAML.parse(yaml: yaml).json(), let obj = json.object {
            return obj
        }
        var obj: [String: JSON] = [:]
        for line in yaml.components(separatedBy: "\n") {
            guard let r = line.range(of: ":") else { continue }
            let key = line[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
            let value = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            obj[key] = .string(value)
        }
        return obj
    }

    static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }

    /// Tags may arrive as a real YAML array or, via the fallback parser, as a
    /// `[a, b]` bracketed string.
    static func parseTags(_ value: JSON?) -> [String] {
        guard let value else { return [] }
        if let arr = value.array {
            return arr.compactMap { $0.string }.filter { !$0.isEmpty }
        }
        guard let s = value.string else { return [] }
        let stripped = s.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return stripped.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func parseDate(_ s: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let d = plain.date(from: s) { return d }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: s)
    }

    static func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
