import Foundation

public protocol EntityReference: Holon, Hashable, Codable {
    var id: EID   { get }
    var taxon: Taxon { get }
}
public typealias EID = String

extension EntityReference {
    public static func randomID() -> EID {
        UUID().uuidString
    }

    public static func shortID(taxon: Taxon = .anything) -> EID {
        let str = UUID().uuidString
        let short = str.dropFirst(str.count - 8).description
        return "\(taxon.description).\(short)"
    }
}

// MARK: - Schema.org entity identity

public protocol SchemaEntityReference: EntityReference {
    static var taxon: Taxon { get }
    var identifier: String? { get }
}

extension SchemaEntityReference {
    public var id: String { identifier ?? taxon.description }
    public var taxon: Taxon { Self.taxon }
}

// MARK: - Hub type conformances

extension Person: SchemaEntityReference {
    public static var taxon: Taxon { .person }
}
extension Person: Entity {}

extension Organization: SchemaEntityReference {
    public static var taxon: Taxon { .org }
}
extension Organization: Entity {}

extension Place: SchemaEntityReference {
    public static var taxon: Taxon { .place }
}
extension Place: Entity {}

extension Plan: SchemaEntityReference {
    public static var taxon: Taxon { .plan }
}
extension Plan: Entity {}

extension Occurrence: SchemaEntityReference {
    public static var taxon: Taxon { .occurrence }
}
extension Occurrence: Entity {}

extension Record: SchemaEntityReference {
    public static var taxon: Taxon { .record }
}
extension Record: Entity {}

extension Collection: SchemaEntityReference {
    public static var taxon: Taxon { .collection }
}
extension Collection: Entity {}

extension Task: SchemaEntityReference {
    public static var taxon: Taxon { .task }
}
extension Task: Entity {}

extension Commitment: SchemaEntityReference {
    public static var taxon: Taxon { .commitment }
}
extension Commitment: Entity {}

extension Outline: SchemaEntityReference {
    public static var taxon: Taxon { .outline }
}
extension Outline: Entity {}

extension Topic: SchemaEntityReference {
    public static var taxon: Taxon { .topic }
}
extension Topic: Entity {}

extension Relationship: SchemaEntityReference {
    public static var taxon: Taxon { .relationship }
}
extension Relationship: Entity {}

extension Artifact: SchemaEntityReference {
    public static var taxon: Taxon { .artifact }
}
extension Artifact: Entity {}

extension Media: SchemaEntityReference {
    public static var taxon: Taxon { .media }
}
extension Media: Entity {}

extension Document: SchemaEntityReference {
    public static var taxon: Taxon { .document }
}
extension Document: Entity {}
