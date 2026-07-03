import Foundation
import Universal

/// Decodes wild-web JSON-LD records (schema.org vocabulary) into hub entities.
///
/// Web pages embed `<script type="application/ld+json">` records whose `@type`
/// uses schema.org names — `Person`, `Organization`, `Event`, `Article`, … .
/// This registry maps those names onto hub types (the hub wins where semantics
/// diverge: schema.org `Event` becomes `Occurrence`) and decodes tolerantly:
/// any record that has no mapping, or fails typed decoding, falls back to a
/// `Document` that preserves the complete raw record in `meta["jsonld"]`.
///
/// The incoming `@type` is stripped before decoding because hub decoders
/// validate `@type` against their own Swift type name (`decodeIfPresent` —
/// absent passes, mismatched throws).
public enum SchemaTypeRegistry {

    /// schema.org `@type` → hub type decode function.
    /// Subtype names are listed explicitly — JSON-LD in the wild rarely uses
    /// deep subtypes beyond these, and unknowns fall back to `Document`.
    private static let decoders: [String: @Sendable (JSON) throws -> any Entity] = {
        var map: [String: @Sendable (JSON) throws -> any Entity] = [:]

        let person: @Sendable (JSON) throws -> any Entity = { try Person(json: $0) }
        let org: @Sendable (JSON) throws -> any Entity = { try Organization(json: $0) }
        let place: @Sendable (JSON) throws -> any Entity = { try Place(json: $0) }
        let occurrence: @Sendable (JSON) throws -> any Entity = { try Occurrence(json: $0) }

        map["Person"] = person
        for name in ["Organization", "Corporation", "NGO", "EducationalOrganization",
                     "GovernmentOrganization", "SportsOrganization", "PerformingGroup"] {
            map[name] = org
        }
        // LocalBusiness is schema.org's Organization-and-Place hybrid; for the
        // hub's purposes the venue identity matters more, so it maps to Place.
        for name in ["Place", "LocalBusiness", "Restaurant", "TouristAttraction",
                     "CivicStructure", "LandmarksOrHistoricalBuildings"] {
            map[name] = place
        }
        for name in ["Event", "MusicEvent", "SportsEvent", "TheaterEvent", "SocialEvent",
                     "Festival", "ScreeningEvent", "EducationEvent", "BusinessEvent"] {
            map[name] = occurrence
        }
        return map
    }()

    /// Decode a single JSON-LD record into the best-fitting hub entity.
    ///
    /// Never fails: unmapped `@type`s and typed-decode errors both fall back
    /// to a `Document` carrying the raw record in `meta["jsonld"]`.
    ///
    /// - Parameters:
    ///   - json: one JSON-LD object (not a `@graph` array — flatten first).
    ///   - sourceURL: the page the record was extracted from; recorded as a
    ///     `web.page` handle on types that carry handles.
    public static func entity(fromJSONLD json: JSON, sourceURL: URL? = nil) -> any Entity {
        let typeName = normalizedTypeName(of: json)

        if let typeName, let decode = decoders[typeName],
           let entity = try? decode(strippingLDKeys(json)) {
            return stamped(entity, sourceURL: sourceURL)
        }
        return document(fromJSONLD: json, typeName: typeName, sourceURL: sourceURL)
    }

    /// Fallback: wrap any JSON-LD record as a `Document`, lifting the common
    /// descriptive fields and preserving the full record in `meta["jsonld"]`.
    public static func document(
        fromJSONLD json: JSON,
        typeName: String? = nil,
        sourceURL: URL? = nil
    ) -> Document {
        let obj = json.object ?? [:]
        var meta: Meta = ["jsonld": json]
        if let typeName { meta["schemaType"] = .string(typeName) }

        var handles: [Handle] = []
        if let sourceURL {
            handles.append(Handle(kind: Handle.Kind.webPage, value: sourceURL.absoluteString))
        }

        return Document(
            identifier: obj["@id"]?.string ?? obj["url"]?.string
                ?? sourceURL?.absoluteString ?? Document.shortID(taxon: .document),
            name: obj["headline"]?.string ?? obj["name"]?.string ?? obj["title"]?.string,
            description: obj["description"]?.string,
            url: (obj["url"]?.string ?? sourceURL?.absoluteString).flatMap(URL.init(string:)),
            contentType: "application/ld+json",
            handles: handles.isEmpty ? nil : handles,
            meta: meta
        )
    }

    // MARK: - Internals

    /// Resolve `@type` to a bare schema.org name: handles URL forms
    /// (`https://schema.org/Person`) and array forms (`["Person", "Author"]`).
    static func normalizedTypeName(of json: JSON) -> String? {
        guard let obj = json.object else { return nil }
        let raw: String?
        switch obj["@type"] {
        case let t where t?.string != nil: raw = t?.string
        case let t where t?.array != nil:  raw = t?.array?.compactMap(\.string).first
        default: raw = nil
        }
        guard let raw else { return nil }
        return raw.split(separator: "/").last.map(String.init)
    }

    /// Remove JSON-LD framing keys that would trip hub decoders' `@type`
    /// validation or add noise. `@id` is kept — hub types decode it as
    /// `identifier`.
    static func strippingLDKeys(_ json: JSON) -> JSON {
        guard var obj = json.object else { return json }
        obj.removeValue(forKey: "@type")
        obj.removeValue(forKey: "@context")
        return .object(obj)
    }

    /// Record provenance (handles / meta) and guarantee a stable identifier —
    /// wild JSON-LD rarely carries `@id`, and search UIs need distinct IDs.
    private static func stamped(_ entity: any Entity, sourceURL: URL?) -> any Entity {
        let handle = sourceURL.map {
            Handle(kind: Handle.Kind.webPage, value: $0.absoluteString)
        }
        switch entity {
        case var p as Person:
            if let handle { p.handles = (p.handles ?? []) + [handle] }
            if p.identifier == nil { p.identifier = Person.shortID(taxon: .person) }
            return p
        case var o as Occurrence:
            if let handle { o.handles = (o.handles ?? []) + [handle] }
            if o.identifier == nil { o.identifier = Occurrence.shortID(taxon: .occurrence) }
            return o
        case var org as Organization:
            if org.identifier == nil { org.identifier = Organization.shortID(taxon: .org) }
            return sourced(org, sourceURL: sourceURL)
        case var place as Place:
            if place.identifier == nil { place.identifier = Place.shortID(taxon: .place) }
            return sourced(place, sourceURL: sourceURL)
        default:
            return sourced(entity, sourceURL: sourceURL)
        }
    }

    /// Fallback provenance for types without handles: record the page in meta.
    private static func sourced(_ entity: any Entity, sourceURL: URL?) -> any Entity {
        guard let sourceURL else { return entity }
        var e = entity
        var meta = e.meta ?? [:]
        meta["sourceURL"] = .string(sourceURL.absoluteString)
        e.meta = meta
        return e
    }
}
