# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build
swift build

# Run all tests
swift test

# Run a single test
swift test --filter OntologyTests/<TestClassName>/<testMethodName>
# Example: swift test --filter OntologyTests/OccurrenceBridgeTests/testBasicProperties
```

CI runs `swift build -v` and `swift test -v` against Swift 6.0, 6.1, and 6.2.

## Architectural direction

The codebase follows a **hub-and-spoke** architecture.

### Hub: this package's own ontology

**This package's types are the hub.** Schema.org, Apple frameworks, Google Suite, OKF, and JSON-LD are all spokes. Where field names happen to align with Schema.org (e.g. `givenName`, `startDate`), that's a convenience — not a commitment. When the ontology's semantics diverge from Schema.org, the ontology wins.

### Holon + Entity

Every meaningful concept in this ontology is a **Holon** — simultaneously:
1. A whole thing in itself (has identity: `taxon` + `id`)
2. Made of parts (contains other holons)
3. Part of something larger (belongs to a parent holon)

**Entity** is a Holon with typed, machine-readable attributes (`Codable`). Concrete types like `Person`, `Place`, `Organization`, `Plan`, `Occurrence` conform to `Entity`.

**Value types** (`DateTime`, `GeoCoordinates`, `QuantitativeValue`) are not Holons — they have no independent identity and live embedded in an Entity's fields.

### Core type vocabulary

The key distinction between `Plan` and `Occurrence` — do not conflate them:

| Type | What it is | Standalone file? |
|---|---|---|
| `Plan` | Intent or template; may carry an RRule and generate Occurrences | Yes |
| `Occurrence` | Atomic space-time fact: a single specific time + place + description | Yes |
| `Record` | Documented outcome: a Plan or Occurrence + what actually happened | Yes |
| `Person` | A person with identity, narrative, relationships | Yes |
| `Organization` | A group, faction, institution | Yes |
| `Place` | A named location with description | Yes |
| `Collection` | A logical grouping of HolonRefs (see below) | Yes (`_index.md`) |
| `RRule` | Recurrence pattern — embedded inside a `Plan`, never standalone | No |
| `DateTime`, `GeoCoordinates`, `QuantitativeValue` | Value types — embedded in parent frontmatter | No |
| Weather types | Transient sensor data, no narrative | No |

`Plan` replaces the old `Event` (abstract) and `PlanAction`. `Occurrence` replaces the old concrete `Event` instance. `Event` and `PlanAction` are still present but marked `@available(*, deprecated)` — use `Plan` and `Occurrence` for all new code.

### Markdown as exchange format

The canonical persistence and exchange format is **one markdown file per Entity**. Files use YAML frontmatter for machine-readable fields and a markdown body for free-form narrative.

```markdown
---
taxon: person
id: person.3f8a91b2
givenName: Jane
familyName: Smith
tags: [npc, innkeeper]
---

Jane has run The Rusty Flagon for thirty years.
```

Frontmatter keys are this ontology's field names (not JSON-LD `@`-prefixed keys). The `taxon` key replaces `@type`; `id` replaces `@id`; `@context` is omitted.

**Reading:** `MarkdownDocument(string:)` / `MarkdownDocument(contentsOf:)` splits the fence, then `FrontmatterParser.decode(_:from:)` runs YAML → JSON → `Decodable` via `universal`.

**Writing:** `MarkdownDocument(_ entity:, body:)` encodes via `JSONEncoder`, normalises keys, serialises to YAML, then `MarkdownDocument.write(to:)` writes atomically.

### HolonRef — two reference modes

```swift
public enum HolonRef: Hashable, Codable, Sendable {
    case entity(Taxon, String)   // [[person.3f8a91b2]] — stable across renames
    case path(String)            // ./assets/portrait.jpg — for assets (images, PDFs)
}
```

Use `.entity` for references between semantic entities. Use `.path` for binary assets co-located with files. Entity refs survive folder reorganization; path refs do not.

WikiLink syntax `[[taxon.id]]` is parsed by `WikiLinkScanner` into `HolonRef.entity` values and scanned from `MarkdownDocument.wikilinks`.

### Physical vs. logical holarchy

The **directory tree** is physical organization (where files live). The **logical holarchy** is conceptual structure (what belongs to what) and may cross directory boundaries.

`_index.md` files (taxon: `collection`) declare logical membership via `HolonRef` lists, independently of the directory layout. A `Person` in `people/jane.md` can be a member of a campaign arc's collection without moving the file.

### Module structure (current)

```
Sources/
  Ontology/           # Hub — pure Swift, Foundation only
    Types/            # Person, Place, Organization, Plan, Occurrence, Record, Collection
    Entities/         # Holon, Entity, HolonRef, Taxon, Identifiers
    Markdown/         # MarkdownDocument, FrontmatterParser, WikiLinkScanner, MarkdownWriter
    Extensions/       # RecurrenceRuleRFC5545FormatStyle (vendored, MIT)
    Schema.swift      # JSONLDCodingKey, schema.org constant

  OntologyApple/      # Spoke — all #if canImport blocks live here
    EventBridge       # EKEvent ↔ Occurrence (canonical), EKEvent ↔ Event (deprecated)
    PlanBridge        # EKReminder → Plan
    PlanActionBridge  # EKReminder → PlanAction (deprecated)
    PersonBridge      # CNContact ↔ Person
    PlaceBridge       # CLPlacemark → Place
    WeatherBridge     # WeatherKit → WeatherConditions / WeatherForecast
    ...

  Presentation/       # SwiftUI views (depends on OntologyApple)
```

`OntologyApple.swift` re-exports `Ontology` via `@_exported import Ontology`.

### All SchemaEntityReference + Entity conformances live in Identifiers.swift

Do not add `SchemaEntityReference` or `Entity` conformances inside type files. All conformances for hub types belong in `Sources/Ontology/Entities/Identifiers.swift`. Deprecated type conformances go at the bottom of that file, marked `@available(*, deprecated)`.

### Entity identity

`Taxon` is a string-backed value type (`ExpressibleByStringLiteral`, `CustomStringConvertible`) used to tag entity kinds. Static constants are declared in `Taxon.swift` (`.person`, `.org`, `.place`, `.plan`, `.occurrence`, `.record`, `.collection`, `.event`).

Entity IDs take the form `taxon.shortHash` (e.g. `person.3f8a91b2`) — stable across file renames and directory reorganization. `EntityReference.shortID(taxon:)` generates them.

### JSON-LD encoding pattern

All hub types use `JSONLDCodingKey<CodingKeys>` for their `Codable` conformance:

- `.context` → `"@context"` (only at root: `encoder.codingPath.isEmpty`)
- `.type` → `"@type"` (always; value is `String(describing: Self.self)`)
- `.id` → `"@id"` (for `identifier`)
- `.attribute(.name)` → `"name"` (for all other fields)

When decoding, validate `@type` conditionally (`decodeIfPresent`) to stay compatible with frontmatter YAML (which has no `@type`).

### DateTime encoding

`DateTime` wraps `Date` + optional `TimeZone`. Timezone resolution priority during encoding: (1) `encoder.userInfo[DateTime.timeZoneOverrideKey]`, (2) the `DateTime`'s own `timeZone`, (3) GMT/UTC.

### Recurrence rules

`RecurrenceRuleRFC5545FormatStyle` implements `FormatStyle` / `ParseStrategy` for `Calendar.RecurrenceRule` ↔ RFC 5545 RRULE strings. Vendored from RRuleKit (MIT). The `Plan.rrule` field stores the RFC 5545 string directly (not a parsed `Calendar.RecurrenceRule`).

### Dependencies

- **universal** (`marcprux/universal`, branch: main) — zero-dep YAML/JSON/XML/PLIST parser; used for frontmatter parsing (YAML → JSON → `Decodable`)
- **Period** — date period/range types
- **YYJSON** (`swift-yyjson`) — fast JSON for Schema.org/JSON-LD spoke output
