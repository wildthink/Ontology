import Foundation

/// A Holon is simultaneously a whole in itself, made of parts, and part of a larger whole.
/// Every meaningful concept in the ontology is a Holon.
public protocol Holon: Sendable {
    var taxon: Taxon { get }
    var id: String { get }
    var whole: HolonRef? { get }
    var parts: [HolonRef] { get }
}

public extension Holon {
    var whole: HolonRef? { nil }
    var parts: [HolonRef] { [] }
}

/// A Holon with typed, machine-readable attributes.
/// Value types (DateTime, GeoCoordinates, etc.) are NOT Entities — they have no
/// independent identity and live embedded in an Entity's fields.
public protocol Entity: Holon, Codable {}
