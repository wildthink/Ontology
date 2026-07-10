import Foundation

// MARK: - IndexPath addressing
//
// Cursor-based access into a catalog forest. An `IndexPath` is a *location*
// (each component indexes into a `children` array; the first indexes the root
// array), never an *identity* — node identity stays the stable string `id`.
// Resolve id → path with `indexPath(ofID:)`, then mutate at the path.
//
// All mutations are forgiving of stale paths: an unresolvable path is a no-op
// (or `nil`), never a trap — paths computed from a rendered snapshot can be
// stale by the time a drop lands.

public extension [OKFCatalogNode] {

    /// The node at `path`, or `nil` when any component is out of range
    /// (an empty path is `nil` — a forest has no root node).
    subscript(indexPath path: IndexPath) -> OKFCatalogNode? {
        var nodes = self
        var node: OKFCatalogNode?
        for index in path {
            guard nodes.indices.contains(index) else { return nil }
            node = nodes[index]
            nodes = node!.children
        }
        return node
    }

    /// Depth-first location of the node with `id`, or `nil` if absent.
    func indexPath(ofID id: String) -> IndexPath? {
        for (index, node) in enumerated() {
            if node.id == id { return IndexPath(index: index) }
            if let sub = node.children.indexPath(ofID: id) {
                return IndexPath(index: index).appending(sub)
            }
        }
        return nil
    }

    /// Removes and returns the node (with its subtree) at `path`.
    /// Returns `nil`, leaving the forest unchanged, when `path` doesn't resolve.
    @discardableResult
    mutating func remove(at path: IndexPath) -> OKFCatalogNode? {
        guard let head = path.first, indices.contains(head) else { return nil }
        if path.count == 1 { return remove(at: head) }
        return self[head].children.remove(at: path.dropFirst())
    }

    /// Removes the nodes at `paths`, returning them in document order.
    /// Paths that don't resolve, duplicates, and paths inside another removed
    /// subtree are dropped.
    @discardableResult
    mutating func remove(at paths: [IndexPath]) -> [OKFCatalogNode] {
        let normalized = normalizing(paths)
        var removed: [OKFCatalogNode] = []
        for path in normalized.reversed() {
            if let node = remove(at: path) { removed.insert(node, at: 0) }
        }
        return removed
    }

    /// Inserts `nodes` contiguously so the first lands at `path`: the container
    /// is `path.dropLast()`, and the final component is the slot among that
    /// container's children (clamped to the valid range, so `count` appends).
    /// No-op when the container doesn't resolve or `nodes` is empty.
    mutating func insert(_ nodes: [OKFCatalogNode], at path: IndexPath) {
        guard !nodes.isEmpty, let head = path.first else { return }
        if path.count == 1 {
            insert(contentsOf: nodes, at: Swift.min(Swift.max(head, 0), count))
            return
        }
        guard indices.contains(head) else { return }
        self[head].children.insert(nodes, at: path.dropFirst())
    }

    /// Single-node convenience for `insert(_:at:)`.
    mutating func insert(_ node: OKFCatalogNode, at path: IndexPath) {
        insert([node], at: path)
    }

    /// Moves the nodes at `paths` (kept in document order) so they land
    /// contiguously at `destination`, expressed in *pre-removal* coordinates —
    /// the slot shift caused by the removals is compensated automatically.
    /// No-op when no source resolves, the destination container doesn't resolve,
    /// or the destination lies inside a moved subtree.
    mutating func move(from paths: [IndexPath], to destination: IndexPath) {
        guard !destination.isEmpty else { return }
        let sources = normalizing(paths)
        guard !sources.isEmpty else { return }
        // A destination inside a dragged subtree has nowhere coherent to land.
        guard !sources.contains(where: { $0.count < destination.count && $0.isPrefix(of: destination) })
        else { return }
        let container = destination.dropLast()
        guard container.isEmpty || self[indexPath: container] != nil else { return }

        let moved = remove(at: sources)
        var slot = destination
        for source in sources where source.count <= slot.count {
            let depth = source.count - 1
            guard source[depth] < slot[depth],
                  (0..<depth).allSatisfy({ source[$0] == slot[$0] })
            else { continue }
            slot[depth] -= 1
        }
        insert(moved, at: slot)
    }

    /// Single-node convenience for `move(from:to:)`.
    mutating func move(from path: IndexPath, to destination: IndexPath) {
        move(from: [path], to: destination)
    }

    /// Valid paths in document order, exact duplicates and descendants of
    /// other listed paths removed.
    private func normalizing(_ paths: [IndexPath]) -> [IndexPath] {
        var out: [IndexPath] = []
        for path in paths.sorted() where self[indexPath: path] != nil {
            guard out.last != path, !out.contains(where: { $0.isPrefix(of: path) }) else { continue }
            out.append(path)
        }
        return out
    }
}

private extension IndexPath {
    func isPrefix(of other: IndexPath) -> Bool {
        count <= other.count && zip(self, other).allSatisfy(==)
    }
}
