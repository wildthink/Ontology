import Foundation
import Markdown

/// A node in the catalog outline — a leaf (item concept) or a section.
///
/// Sections are normally concept-backed (`type: Section`, with their own file);
/// a section with no backing concept is a plain-text line in the index, tolerated
/// on parse for robustness.
public struct OKFCatalogNode: Identifiable, Hashable, Sendable {
    /// `concept.id` when concept-backed; a stable derived id otherwise.
    public var id: String
    public var title: String
    public var concept: OKFConcept?
    public var children: [OKFCatalogNode]

    /// A node with no concept is treated as a section (structure, not content).
    public var isSection: Bool { concept?.isSection ?? true }

    public init(concept: OKFConcept) {
        self.id = concept.id
        self.title = concept.displayTitle
        self.concept = concept
        self.children = []
    }

    public init(sectionTitle: String, id: String = UUID().uuidString, children: [OKFCatalogNode] = []) {
        self.id = id
        self.title = sectionTitle
        self.concept = nil
        self.children = children
    }

    /// All *item* concepts in this subtree (section concepts excluded — they're structure).
    public var allConcepts: [OKFConcept] {
        if isSection { return children.flatMap(\.allConcepts) }
        return concept.map { [$0] } ?? []
    }

    /// Every concept backing a file in this subtree, sections included — what serialization walks.
    public var allFileConcepts: [OKFConcept] {
        var out: [OKFConcept] = []
        if let concept { out.append(concept) }
        out += children.flatMap(\.allFileConcepts)
        return out
    }

    /// A copy with `deletedAt` set (or cleared) on every concept in the subtree.
    public func stampingDeleted(_ date: Date?) -> OKFCatalogNode {
        var n = self
        n.concept?.deletedAt = date
        n.children = children.map { $0.stampingDeleted(date) }
        return n
    }

    /// Like `stampingDeleted`, but preserves existing stamps (hand-moved items get stamped now,
    /// already-trashed items keep their original decay clock).
    public func stampingDeletedIfMissing(_ date: Date) -> OKFCatalogNode {
        var n = self
        if n.concept != nil, n.concept?.deletedAt == nil { n.concept?.deletedAt = date }
        n.children = children.map { $0.stampingDeletedIfMissing(date) }
        return n
    }
}

public extension [OKFCatalogNode] {
    var allConcepts: [OKFConcept] { flatMap(\.allConcepts) }
    var allFileConcepts: [OKFConcept] { flatMap(\.allFileConcepts) }

    /// Removes sections that contain no concepts anywhere in their subtree.
    func pruningEmptySections() -> [OKFCatalogNode] {
        compactMap { node in
            guard node.isSection else { return node }
            var n = node
            n.children = n.children.pruningEmptySections()
            return n.children.isEmpty ? nil : n
        }
    }
}

/// The pure OKF catalog format: read/write of the `index.md` structure and the
/// per-concept files, with no file-system or `FileWrapper` coupling.
///
/// A host drives IO and hands this type the raw text:
/// - `parse(indexText:itemFiles:trashFiles:)` reconstructs the live and trash trees.
/// - `serialize(purgingTrashBefore:title:)` produces the index text and the concept
///   file texts to persist (applying save-time trash decay).
///
/// `itemFiles` and `trashFiles` are keyed by a concept's canonical bundle-relative
/// id (`items/<uuid>.md`). Trashed concept files physically park elsewhere
/// (`trash/…`) in a bundle, but keep their canonical id — the host maps between the
/// two; this layer only ever sees canonical ids.
public struct OKFCatalog: Sendable {
    public var outline: [OKFCatalogNode]
    public var trash: [OKFCatalogNode]
    /// Opaque document-level frontmatter (e.g. a display style). Preserved verbatim;
    /// the host interprets it. `nil` when the index carries no frontmatter.
    public var style: [String: String]?

    public init(
        outline: [OKFCatalogNode] = [],
        trash: [OKFCatalogNode] = [],
        style: [String: String]? = nil
    ) {
        self.outline = outline
        self.trash = trash
        self.style = style
    }

    public init(concepts: [OKFConcept]) {
        self.outline = concepts.map(OKFCatalogNode.init(concept:))
        self.trash = []
        self.style = nil
    }

    public var concepts: [OKFConcept] { outline.allConcepts }

    // MARK: - Read

    /// Reconstruct a catalog from raw index text and concept file texts.
    ///
    /// `index.md` is the source of truth for structure: the first list is the live
    /// outline; the first list under a `## Trash` heading is the trash. Physical
    /// origin breaks ties for orphans (files present but unlisted): item orphans
    /// re-append live, trash orphans re-append to trash.
    public static func parse(
        indexText: String?,
        itemFiles: [String: String],
        trashFiles: [String: String] = [:]
    ) -> OKFCatalog {
        var byPath: [String: OKFConcept] = [:]
        for (path, text) in itemFiles {
            if let c = OKFConcept(id: path, markdown: text) { byPath[path] = c }
        }
        var trashByPath: [String: OKFConcept] = [:]
        for (path, text) in trashFiles {
            if let c = OKFConcept(id: path, markdown: text), byPath[c.id] == nil {
                trashByPath[c.id] = c
            }
        }

        guard let indexText else {
            let outline = byPath.values
                .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
                .map { OKFCatalogNode(concept: $0) }
            let trash = trashByPath.values
                .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
                .map { OKFCatalogNode(concept: $0) }
            return OKFCatalog(outline: outline, trash: trash.pruningEmptySections())
        }

        let (frontmatter, body) = splitFrontmatter(indexText)
        let combined = byPath.merging(trashByPath) { live, _ in live }
        let regions = parseIndexRegions(body, concepts: combined)
        var outline = regions.live
        var trash = regions.trash

        let listed = Set((outline + trash).allFileConcepts.map(\.id))
        outline += byPath.values
            .filter { !listed.contains($0.id) && !$0.isSection }
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
            .map { OKFCatalogNode(concept: $0) }
        trash += trashByPath.values
            .filter { !listed.contains($0.id) && !$0.isSection }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
            .map { OKFCatalogNode(concept: $0) }

        return OKFCatalog(outline: outline, trash: trash.pruningEmptySections(), style: frontmatter)
    }

    // MARK: - Write

    /// The index.md text for the current outline+trash (no decay applied).
    public func indexText(title: String = "Catalog") -> String {
        makeIndex(outline, trash: trash, title: title, style: style)
    }

    /// Serialize the catalog. `purgingTrashBefore` applies save-time decay: trashed
    /// concepts whose `deletedAt` predates the cutoff are dropped (and sections left
    /// empty by that are pruned). `nil` keeps trash forever.
    ///
    /// Returns the index text plus concept file texts keyed by canonical id. Trash
    /// files are returned separately (also keyed by canonical id) so the host can park
    /// them under `trash/` while preserving that id.
    public func serialize(
        purgingTrashBefore cutoff: Date? = nil,
        title: String = "Catalog"
    ) -> (indexText: String, itemFiles: [String: String], trashFiles: [String: String]) {
        var items: [String: String] = [:]
        for concept in outline.allFileConcepts {
            items[concept.id] = concept.markdownString()
        }
        let keptTrash = Self.pruningTrash(trash, cutoff: cutoff)
        var trashOut: [String: String] = [:]
        for concept in keptTrash.allFileConcepts {
            trashOut[concept.id] = concept.markdownString()
        }
        let index = makeIndex(outline, trash: keptTrash, title: title, style: style)
        return (index, items, trashOut)
    }

    // MARK: - Raw index editing

    /// Re-derive a catalog from edited index text, reusing this catalog's concepts as
    /// the pool. Moving a line across the `## Trash` heading trashes (stamping now) or
    /// restores (clearing the stamp). Concepts whose lines were deleted re-append where
    /// they previously lived rather than being destroyed; unlisted section concepts are
    /// dropped as dead structure.
    public func parsing(indexText text: String) -> OKFCatalog {
        let (frontmatter, body) = Self.splitFrontmatter(text)
        let byPath = Dictionary(
            (outline + trash).allFileConcepts.map { ($0.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        let regions = Self.parseIndexRegions(body, concepts: byPath)
        var live = regions.live.map { $0.stampingDeleted(nil) }
        var newTrash = regions.trash.map { $0.stampingDeletedIfMissing(.now) }

        let listed = Set((live + newTrash).allFileConcepts.map(\.id))
        let previouslyLive = Set(outline.allFileConcepts.map(\.id))
        let orphans = byPath.values.filter { !listed.contains($0.id) && !$0.isSection }
        live += orphans
            .filter { previouslyLive.contains($0.id) }
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
            .map { OKFCatalogNode(concept: $0) }
        newTrash += orphans
            .filter { !previouslyLive.contains($0.id) }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
            .map { OKFCatalogNode(concept: $0) }

        return OKFCatalog(outline: live, trash: newTrash.pruningEmptySections(), style: frontmatter)
    }

    // MARK: - Decay

    private static func pruningTrash(_ nodes: [OKFCatalogNode], cutoff: Date?) -> [OKFCatalogNode] {
        nodes.compactMap { node in
            if node.isSection {
                var n = node
                n.children = pruningTrash(node.children, cutoff: cutoff)
                return n.children.isEmpty ? nil : n
            }
            if let cutoff, let deleted = node.concept?.deletedAt, deleted < cutoff { return nil }
            return node
        }
    }

    // MARK: - Index frontmatter

    /// Split a leading `---` block off index text (same minimal `key: value` dialect
    /// as concept files). Returns `nil` frontmatter when the text has no block.
    static func splitFrontmatter(_ text: String) -> (frontmatter: [String: String]?, body: String) {
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let end = lines.dropFirst().firstIndex(where: {
                  $0.trimmingCharacters(in: .whitespaces) == "---"
              })
        else { return (nil, text) }
        var pairs: [String: String] = [:]
        for line in lines[1..<end] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else { continue }
            pairs[key] = value
        }
        return (pairs, lines[(end + 1)...].joined(separator: "\n"))
    }

    // MARK: - Index writing

    private func makeIndex(
        _ nodes: [OKFCatalogNode],
        trash trashNodes: [OKFCatalogNode],
        title: String,
        style: [String: String]?
    ) -> String {
        var lines: [String] = []
        if let style, !style.isEmpty {
            lines.append("---")
            lines += style.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
            lines += ["---", ""]
        }
        lines += ["# \(title)", ""]
        appendNodes(nodes, to: &lines, indent: "")
        if !trashNodes.isEmpty {
            lines += ["", "## Trash", ""]
            appendNodes(trashNodes, to: &lines, indent: "")
        }
        return lines.joined(separator: "\n")
    }

    private func appendNodes(_ nodes: [OKFCatalogNode], to lines: inout [String], indent: String) {
        for node in nodes {
            if let concept = node.concept {
                lines.append("\(indent)- [\(concept.displayTitle)](\(concept.id))")
            } else {
                lines.append("\(indent)- \(node.title)")
            }
            if node.isSection {
                appendNodes(node.children, to: &lines, indent: indent + "  ")
            }
        }
    }

    // MARK: - Index parsing (nested markdown list, via swift-markdown)

    /// Split index body into live/trash regions: the first list before any `## Trash`
    /// heading is the live outline; the first list after it is the trash. Any other
    /// heading ends the trash region.
    static func parseIndexRegions(
        _ text: String, concepts: [String: OKFConcept]
    ) -> (live: [OKFCatalogNode], trash: [OKFCatalogNode]) {
        let document = Document(parsing: text)
        var live: [OKFCatalogNode]?
        var trashRegion: [OKFCatalogNode]?
        var inTrash = false
        for block in document.children {
            if let heading = block as? Heading {
                inTrash = heading.level == 2
                    && heading.plainText.trimmingCharacters(in: .whitespaces) == "Trash"
                continue
            }
            guard let list = block as? UnorderedList else { continue }
            let nodes = Array(list.listItems.map { parseListItem($0, concepts: concepts) })
            if inTrash {
                if trashRegion == nil { trashRegion = nodes }
            } else if live == nil {
                live = nodes
            }
        }
        var used: Set<String> = []
        return (
            assigningStableSectionIDs(live ?? [], used: &used),
            assigningStableSectionIDs(trashRegion ?? [], used: &used)
        )
    }

    /// Plain-text sections have no backing concept and no persisted id (the index carries
    /// only their title), so give them a deterministic id derived from their title path,
    /// disambiguated by encounter order. Concept-backed nodes keep their stable file id.
    private static func assigningStableSectionIDs(
        _ nodes: [OKFCatalogNode], used: inout Set<String>
    ) -> [OKFCatalogNode] {
        func walk(_ nodes: [OKFCatalogNode], prefix: String) -> [OKFCatalogNode] {
            nodes.map { node in
                var n = node
                let path = prefix.isEmpty ? node.title : prefix + "/" + node.title
                if n.concept == nil {
                    var candidate = "sec:" + path
                    var bump = 2
                    while used.contains(candidate) { candidate = "sec:\(path)#\(bump)"; bump += 1 }
                    n.id = candidate
                    used.insert(candidate)
                }
                n.children = walk(node.children, prefix: path)
                return n
            }
        }
        return walk(nodes, prefix: "")
    }

    private static func parseListItem(_ item: ListItem, concepts: [String: OKFConcept]) -> OKFCatalogNode {
        var node = OKFCatalogNode(sectionTitle: "")
        var children: [OKFCatalogNode] = []
        for block in item.blockChildren {
            if let paragraph = block as? Paragraph {
                node = parseNodeContent(paragraph, concepts: concepts)
            } else if let sublist = block as? UnorderedList {
                children = sublist.listItems.map { parseListItem($0, concepts: concepts) }
            }
        }
        node.children = children
        return node
    }

    /// Parse a list item's paragraph: a single `[title](path)` link resolving to a known
    /// concept, or plain text (a section).
    private static func parseNodeContent(_ paragraph: Paragraph, concepts: [String: OKFConcept]) -> OKFCatalogNode {
        let inline = Array(paragraph.children)
        if inline.count == 1, let link = inline[0] as? Link {
            let title = link.children.compactMap { ($0 as? Text)?.string }.joined()
            if let path = link.destination, let concept = concepts[path] {
                return OKFCatalogNode(concept: concept)
            }
            return OKFCatalogNode(sectionTitle: title)
        }
        let title = inline.compactMap { ($0 as? Text)?.string }.joined()
        return OKFCatalogNode(sectionTitle: title)
    }
}
