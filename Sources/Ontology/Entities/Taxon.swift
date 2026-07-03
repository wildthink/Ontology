//
//  Taxon.swift
//  Ontology
//
//  Created by Jason Jobe on 4/23/26.
//

public struct Taxon: Identifiable,
                     Sendable, Hashable, Equatable
{
    public typealias Representation = String // Char10
    
    public var id: Int { hashValue }
    public let representation: Representation
    
    public init(_ str: Representation) {
        self.representation = str
    }
}

public extension Taxon {
    static let anything: Taxon = "any"
    static let agent: Taxon = "agent"
    static let person: Taxon = "person"
    static let org: Taxon = "org"
    
    static let place: Taxon = "place"

    static let event: Taxon = "event"
    static let topic: Taxon = "topic"

    static let plan: Taxon = "plan"
    static let occurrence: Taxon = "occurrence"
    static let record: Taxon = "record"
    static let collection: Taxon = "collection"
    static let task: Taxon = "task"
    static let commitment: Taxon = "commitment"
    static let outline: Taxon = "outline"
    static let relationship: Taxon = "relationship"
    static let artifact: Taxon = "artifact"
    static let media: Taxon = "media"
    static let tool: Taxon = "tool"
    static let frame: Taxon = "frame"
}

extension Taxon: Codable {
   public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.representation = value // Word64(stringLiteral: value)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.representation)
    }
}

extension Taxon: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.representation = value
    }
}

extension Taxon: CustomStringConvertible {
    public var description: String {
        representation
    }
}

// MARK: Core Types Names
public typealias CoreType = Char10
public extension CoreType {
    static let text: CoreType = "text"
    static let data: CoreType = "data"
    static let json: CoreType = "json"
    static let ecs:  CoreType = "ecs"
}

public typealias SubType = Char10
public extension SubType {
    static let ical: CoreType = "iCal"
    static let jcal: CoreType = "jCal"
    
    /// Google Calendar JSON/
    static let gcal: CoreType = "gCal"
}

// MARK: TaxonInfo - Schema.org
/// We store the Taxon details seperately to avoid the overhead
/// of embedding the "metadata" in the `taxon` properties of
/// entities.
///

