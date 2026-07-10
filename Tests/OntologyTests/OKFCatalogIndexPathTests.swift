import Foundation
import Testing
import OntologyOKF

@Suite("OKF Catalog IndexPath addressing")
struct OKFCatalogIndexPathTests {

    // Fixture forest:
    //   [0] Section A
    //     [0,0] a1
    //     [0,1] a2
    //   [1] Section B
    //     [1,0] b1
    //   [2] c
    static func makeForest() -> [OKFCatalogNode] {
        var a = OKFCatalogNode(sectionTitle: "A", id: "A")
        a.children = [leaf("a1"), leaf("a2")]
        var b = OKFCatalogNode(sectionTitle: "B", id: "B")
        b.children = [leaf("b1")]
        return [a, b, leaf("c")]
    }

    static func leaf(_ id: String) -> OKFCatalogNode {
        OKFCatalogNode(concept: OKFConcept(id: id, type: "Website", title: id))
    }

    func ids(_ nodes: [OKFCatalogNode]) -> [String] { nodes.map(\.id) }

    // MARK: - Subscript

    @Test func subscriptResolvesNestedPaths() {
        let forest = Self.makeForest()
        #expect(forest[indexPath: IndexPath(index: 0)]?.id == "A")
        #expect(forest[indexPath: IndexPath(indexes: [0, 1])]?.id == "a2")
        #expect(forest[indexPath: IndexPath(indexes: [1, 0])]?.id == "b1")
        #expect(forest[indexPath: IndexPath(index: 2)]?.id == "c")
    }

    @Test func subscriptRejectsInvalidPaths() {
        let forest = Self.makeForest()
        #expect(forest[indexPath: IndexPath()] == nil)
        #expect(forest[indexPath: IndexPath(index: 3)] == nil)
        #expect(forest[indexPath: IndexPath(indexes: [0, 5])] == nil)
        #expect(forest[indexPath: IndexPath(indexes: [2, 0])] == nil)  // leaf has no children
    }

    // MARK: - indexPath(ofID:)

    @Test func indexPathOfIDFindsNodesAtEveryDepth() {
        let forest = Self.makeForest()
        #expect(forest.indexPath(ofID: "A") == IndexPath(index: 0))
        #expect(forest.indexPath(ofID: "a2") == IndexPath(indexes: [0, 1]))
        #expect(forest.indexPath(ofID: "b1") == IndexPath(indexes: [1, 0]))
        #expect(forest.indexPath(ofID: "c") == IndexPath(index: 2))
        #expect(forest.indexPath(ofID: "missing") == nil)
    }

    // MARK: - Remove

    @Test func removeAtPathReturnsSubtree() {
        var forest = Self.makeForest()
        let removed = forest.remove(at: IndexPath(index: 0))
        #expect(removed?.id == "A")
        #expect(removed?.children.count == 2)
        #expect(ids(forest) == ["B", "c"])
    }

    @Test func removeAtNestedPath() {
        var forest = Self.makeForest()
        let removed = forest.remove(at: IndexPath(indexes: [0, 0]))
        #expect(removed?.id == "a1")
        #expect(ids(forest[0].children) == ["a2"])
    }

    @Test func removeAtInvalidPathIsNoOp() {
        var forest = Self.makeForest()
        #expect(forest.remove(at: IndexPath(indexes: [4, 0])) == nil)
        #expect(forest.remove(at: IndexPath()) == nil)
        #expect(ids(forest) == ["A", "B", "c"])
    }

    @Test func removeManyReturnsDocumentOrderAndDropsDescendants() {
        var forest = Self.makeForest()
        // Passed out of order, includes a descendant of a removed subtree and a dupe.
        let removed = forest.remove(at: [
            IndexPath(index: 2),
            IndexPath(indexes: [0, 1]),
            IndexPath(index: 0),
            IndexPath(index: 0),
        ])
        #expect(ids(removed) == ["A", "c"])
        #expect(ids(forest) == ["B"])
    }

    // MARK: - Insert

    @Test func insertManyAtRootSlot() {
        var forest = Self.makeForest()
        forest.insert([Self.leaf("x"), Self.leaf("y")], at: IndexPath(index: 1))
        #expect(ids(forest) == ["A", "x", "y", "B", "c"])
    }

    @Test func insertIntoSectionChildren() {
        var forest = Self.makeForest()
        forest.insert(Self.leaf("x"), at: IndexPath(indexes: [1, 1]))
        #expect(ids(forest[1].children) == ["b1", "x"])
    }

    @Test func insertClampsSlotAndIgnoresInvalidContainer() {
        var forest = Self.makeForest()
        forest.insert(Self.leaf("x"), at: IndexPath(index: 99))   // clamped to end
        #expect(ids(forest) == ["A", "B", "c", "x"])
        forest.insert(Self.leaf("y"), at: IndexPath(indexes: [9, 0]))  // no such container
        #expect(forest.count == 4)
    }

    // MARK: - Move

    @Test func moveWithinSameParentAdjustsForRemoval() {
        var forest = Self.makeForest()
        // Move A (index 0) after c (slot 3 pre-removal): lands at end.
        forest.move(from: IndexPath(index: 0), to: IndexPath(index: 3))
        #expect(ids(forest) == ["B", "c", "A"])
    }

    @Test func moveEarlierInSameParent() {
        var forest = Self.makeForest()
        forest.move(from: IndexPath(index: 2), to: IndexPath(index: 0))
        #expect(ids(forest) == ["c", "A", "B"])
    }

    @Test func moveAcrossParentsIntoSection() {
        var forest = Self.makeForest()
        // c → first child of B
        forest.move(from: IndexPath(index: 2), to: IndexPath(indexes: [1, 0]))
        #expect(ids(forest) == ["A", "B"])
        #expect(ids(forest[1].children) == ["c", "b1"])
    }

    @Test func moveManyFromDifferentParentsLandsContiguously() {
        var forest = Self.makeForest()
        // a1 and c → into B after b1. Sources are in pre-removal coordinates.
        forest.move(
            from: [IndexPath(indexes: [0, 0]), IndexPath(index: 2)],
            to: IndexPath(indexes: [1, 1])
        )
        #expect(ids(forest) == ["A", "B"])
        #expect(ids(forest[0].children) == ["a2"])
        #expect(ids(forest[1].children) == ["b1", "a1", "c"])
    }

    @Test func moveManySiblingsPreservesDocumentOrder() {
        var forest = Self.makeForest()
        // a2 then a1 passed out of order; both to root end.
        forest.move(
            from: [IndexPath(indexes: [0, 1]), IndexPath(indexes: [0, 0])],
            to: IndexPath(index: 3)
        )
        #expect(ids(forest) == ["A", "B", "c", "a1", "a2"])
        #expect(forest[0].children.isEmpty)
    }

    @Test func moveIntoOwnSubtreeIsNoOp() {
        var forest = Self.makeForest()
        forest.move(from: IndexPath(index: 0), to: IndexPath(indexes: [0, 1]))
        #expect(ids(forest) == ["A", "B", "c"])
        #expect(ids(forest[0].children) == ["a1", "a2"])
    }

    @Test func moveWithStaleSourceIsNoOp() {
        var forest = Self.makeForest()
        forest.move(from: IndexPath(indexes: [5, 5]), to: IndexPath(index: 0))
        #expect(ids(forest) == ["A", "B", "c"])
    }

    @Test func moveSectionAheadOfDeeperDestinationAdjustsAncestorComponent() {
        var forest = Self.makeForest()
        // Move section A (root index 0) into B — B's pre-removal path is [1],
        // so the destination [1, 1] must shift to [0, 1] after A is removed.
        forest.move(from: IndexPath(index: 0), to: IndexPath(indexes: [1, 1]))
        #expect(ids(forest) == ["B", "c"])
        #expect(ids(forest[0].children) == ["b1", "A"])
        #expect(ids(forest[0].children[1].children) == ["a1", "a2"])
    }
}

@Suite("OKF Catalog editing")
struct OKFCatalogEditingTests {

    func makeCatalog() -> OKFCatalog {
        OKFCatalog(outline: OKFCatalogIndexPathTests.makeForest())
    }

    func ids(_ nodes: [OKFCatalogNode]) -> [String] { nodes.map(\.id) }

    @Test func trashStampsSubtreeAndRemovesFromOutline() {
        var catalog = makeCatalog()
        let now = Date()
        catalog.trash(id: "A", now: now)
        #expect(ids(catalog.outline) == ["B", "c"])
        #expect(ids(catalog.trash) == ["A"])
        #expect(catalog.trash[0].children.allSatisfy { $0.concept?.deletedAt == now })
    }

    @Test func trashDropsEmptySectionOutright() {
        var catalog = makeCatalog()
        catalog.outline.append(OKFCatalogNode(sectionTitle: "Empty", id: "E"))
        catalog.trash(id: "E")
        #expect(catalog.trash.isEmpty)
        #expect(catalog.outline.indexPath(ofID: "E") == nil)
    }

    @Test func restoreClearsStampAndAppendsToRoot() {
        var catalog = makeCatalog()
        catalog.trash(id: "c")
        catalog.restore(id: "c")
        #expect(ids(catalog.outline) == ["A", "B", "c"])
        #expect(catalog.trash.isEmpty)
        #expect(catalog.outline.last?.concept?.deletedAt == nil)
    }

    @Test func purgeDeletesTrashedNodeAndPrunesEmptySections() {
        var catalog = makeCatalog()
        catalog.trash(id: "B")  // section with one item, lands in trash
        catalog.purge(id: "b1")
        #expect(catalog.trash.isEmpty)  // B left empty → pruned
    }

    @Test func editingWithUnknownIDIsNoOp() {
        var catalog = makeCatalog()
        catalog.trash(id: "nope")
        catalog.restore(id: "nope")
        catalog.purge(id: "nope")
        #expect(ids(catalog.outline) == ["A", "B", "c"])
        #expect(catalog.trash.isEmpty)
    }
}
