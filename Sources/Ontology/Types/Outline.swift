import Foundation

/// A node in a hierarchical outline/catalog.
///
/// Value type — no independent identity; lives embedded inside an `Outline`.
/// A node is either a pure label (e.g. a section heading with no backing
/// entity) or a pointer to a real Holon via `ref`, decorated with
/// outline-specific metadata (`note`, `tags`) that doesn't belong on the
/// referenced entity itself — the same entity can be annotated differently
/// in different outlines.
public struct OutlineNode: Hashable, Sendable {
    public var title: String
    /// Optional pointer to a full Holon this node represents.
    public var ref: HolonRef?
    public var note: String?
    public var tags: [String]?
    public var children: [OutlineNode]

    /// Open, schema-free metadata (see `Meta`).
    public var meta: Meta?

    public init(
        title: String,
        ref: HolonRef? = nil,
        note: String? = nil,
        tags: [String]? = nil,
        children: [OutlineNode] = []
    ) {
        self.title = title
        self.ref = ref
        self.note = note
        self.tags = tags
        self.children = children
    }
}

extension OutlineNode: Codable {
    private enum CodingKeys: String, CodingKey {
        case meta
        case title, ref, note, tags, children
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        try container.encodeJSONLDHeader(Self.self, encoder: encoder)
        try container.encodeIfPresent(meta, forKey: .attribute(.meta))

        try container.encode(title, forKey: .attribute(.title))
        try container.encodeIfPresent(ref, forKey: .attribute(.ref))
        try container.encodeIfPresent(note, forKey: .attribute(.note))
        try container.encodeIfPresent(tags, forKey: .attribute(.tags))
        if !children.isEmpty {
            try container.encode(children, forKey: .attribute(.children))
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        _ = try container.decodeJSONLDHeader(Self.self)
        title = try container.decode(String.self, forKey: .attribute(.title))
        ref = try container.decodeIfPresent(HolonRef.self, forKey: .attribute(.ref))
        note = try container.decodeIfPresent(String.self, forKey: .attribute(.note))
        tags = try container.decodeIfPresent([String].self, forKey: .attribute(.tags))
        children = try container.decodeIfPresent([OutlineNode].self, forKey: .attribute(.children)) ?? []
    }
}

/// A hierarchical catalog: an ordered tree of labeled, optionally-referenced
/// nodes. Persisted as one markdown file, independent of directory layout —
/// same relationship to `Collection` that a table of contents has to a
/// folder listing.
///
/// ```markdown
/// ---
/// taxon: outline
/// id: outline.campaign-toc
/// name: Campaign Table of Contents
/// nodes:
///   - title: Act I — The Dragon Arc
///     note: Introduces the goblin lair
///     children:
///       - title: Session 1
///         ref: [[occurrence.s01]]
/// ---
/// ```
public struct Outline: Hashable, Sendable {
    public var identifier: String?
    public var name: String?
    public var description: String?
    public var nodes: [OutlineNode]

    /// Open, schema-free metadata (see `Meta`).
    public var meta: Meta?

    public init(
        identifier: String? = nil,
        name: String? = nil,
        description: String? = nil,
        nodes: [OutlineNode] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.nodes = nodes
    }
}

extension Outline: Codable {
    private enum CodingKeys: String, CodingKey {
        case meta
        case name, description, nodes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        try container.encodeJSONLDHeader(Self.self, id: identifier, encoder: encoder)
        try container.encodeIfPresent(meta, forKey: .attribute(.meta))
        try container.encodeIfPresent(name, forKey: .attribute(.name))
        try container.encodeIfPresent(description, forKey: .attribute(.description))
        if !nodes.isEmpty {
            try container.encode(nodes, forKey: .attribute(.nodes))
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)

        identifier = try container.decodeJSONLDHeader(Self.self)

        meta = try container.decodeIfPresent(Meta.self, forKey: .attribute(.meta))
        name = try container.decodeIfPresent(String.self, forKey: .attribute(.name))
        description = try container.decodeIfPresent(String.self, forKey: .attribute(.description))
        nodes = try container.decodeIfPresent([OutlineNode].self, forKey: .attribute(.nodes)) ?? []
    }
}
