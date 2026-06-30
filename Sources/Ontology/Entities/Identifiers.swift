//
//  Identifiers.swift
//  Ontology
//
//  Created by Jason Jobe on 4/23/26.
//

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
        let short = str.dropFirst(str.count-8).description
        return "\(taxon.description).\(short)"
    }
}

// MARK: Schema.org Entities
public protocol SchemaEntityReference: EntityReference {
    static var taxon: Taxon { get }
    var identifier: String? { get }
}

extension SchemaEntityReference {
    public var id: String {
        identifier ?? taxon.description
    }
    public var taxon: Taxon { Self.taxon }
}

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

extension Event: SchemaEntityReference {
    public static var taxon: Taxon { .event }
}
extension Event: Entity {}
