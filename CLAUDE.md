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
# Example: swift test --filter OntologyTests/OccurrenceTests/testEncoding
```

CI runs `swift build -v` and `swift test -v` against Swift 6.0, 6.1, and 6.2.

## Architectural direction

The codebase is in active redesign toward a **hub-and-spoke** architecture. What follows describes both the current state and the intended direction. When adding or refactoring code, prefer the intended direction.

### Hub: this package's own ontology

**This package's types are the hub.** Schema.org, Apple frameworks, Google Suite, OKF, and JSON-LD are all spokes. Where field names happen to align with Schema.org (e.g. `givenName`, `startDate`), that's a convenience — not a commitment. When the ontology's semantics diverge from Schema.org, the ontology wins.

### Holon + Entity

Every meaningful concept in this ontology is a **Holon** — simultaneously:
1. A whole thing in itself (has identity: `taxon` + `id`)
2. Made of parts (contains other holons)
3. Part of something larger (belongs to a parent holon)

**Entity** is a Holon with typed, machine-readable attributes (`Codable`). Concrete types like `Person`, `Place`, `Organization`, `Plan`, `Occurrence` conform to `Entity`.

**Value types** (`DateTime`, `GeoCoordinates`, `QuantitativeValue`, `RRule`) are not Holons — they have no independent identity and live embedded in an Entity's fields.

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

`Plan` replaces the old `Event` (abstract) and `PlanAction`. `Occurrence` replaces the old concrete `Event` instance. `RRule` is never a file — it lives in the `Plan`'s frontmatter.

### Markdown as exchange format

The canonical persistence and exchange format is **one markdown file per Entity**. Files use YAML frontmatter for machine-readable fields and a markdown body for free-form narrative.

```markdown
---
taxon: person
id: person.3f8a91b2
givenName: Jane
familyName: Smith
worksFor: "[[org.4c2d7e1a]]"
tags: [npc, innkeeper]
---

Jane has run The Rusty Flagon for thirty years.
```

Frontmatter keys are this ontology's field names. The YAML parser is `universal` (see Dependencies), which converts YAML → JSON → standard `Decodable`.

### HolonRef — two reference modes

```swift
public enum HolonRef: Hashable, Codable, Sendable {
    case entity(Taxon, String)   // [[person.3f8a91b2]] — stable across renames
    case path(String)            // ./assets/portrait.jpg — for assets (images, PDFs)
}
```

Use `.entity` for references between semantic entities. Use `.path` for binary assets co-located with files. Entity refs survive folder reorganization; path refs do not.

### Physical vs. logical holarchy

The **directory tree** is physical organization (where files live). The **logical holarchy** is conceptual structure (what belongs to what) and may cross directory boundaries.

`_index.md` files (taxon: `collection`) declare logical membership via `HolonRef` lists, independently of the directory layout. A `Person` in `people/jane.md` can be a member of a campaign arc's collection without moving the file.

### Target structure (intended)

```
Sources/
  Ontology/           # Hub — pure Swift, Foundation only
    Types/            # Person, Place, Organization, Plan, Occurrence, Record
    Entities/         # Holon, Entity, HolonRef, Taxon, Identifiers, Word64
    Markdown/         # MarkdownDocument, FrontmatterParser (via universal), WikiLinkScanner
    JSON-LD.swift     # JSONLDCodingKey — Schema.org spoke serialization infrastructure
    Schema.swift

  OntologyApple/      # Spoke — all #if canImport blocks live here, not in hub types
  OntologyGoogle/     # Spoke (future)
  Presentation/       # SwiftUI views (depends on Ontology only)
```

Apple bridging (`#if canImport(Contacts)`, `#if canImport(EventKit)`, etc.) currently lives inside hub type files. It should move to `OntologyApple/` so spoke changes don't touch hub types.

### Current state (before refactor)

Hub types still use Schema.org naming conventions and embed Apple bridging directly. The `#if canImport(...)` pattern is scattered through `Sources/Ontology/Types/`. The JSON-LD encoding pattern (`JSONLDCodingKey<T>`) is in place and will remain as the Schema.org spoke's serialization layer.

### Entity identity

`Taxon` is a compact string-backed value type (stored as `Word64`/`Char10`, a 6-bit-packed Int64, max 10 alphanumeric chars) used to tag entity kinds. `Word64` is `ExpressibleByStringLiteral` for ergonomic call sites.

Entity IDs take the form `taxon.shortHash` (e.g. `person.3f8a91b2`) — stable across file renames and directory reorganization.

### DateTime encoding

`DateTime` wraps `Date` + optional `TimeZone`. Timezone resolution priority during encoding: (1) `encoder.userInfo[DateTime.timeZoneOverrideKey]`, (2) the `DateTime`'s own `timeZone`, (3) GMT/UTC.

### Recurrence rules

`RecurrenceRuleRFC5545FormatStyle` implements `FormatStyle` / `ParseStrategy` for `Calendar.RecurrenceRule` ↔ RFC 5545 RRULE strings. Vendored from RRuleKit (MIT). Belongs inside `Plan`'s frontmatter — not a standalone entity.

### Dependencies

- **universal** (`marcprux/universal`) — zero-dep YAML/JSON/XML/PLIST parser; used for frontmatter parsing (YAML → JSON → `Decodable`)
- **Period** — date period/range types
- **YYJSON** (`swift-yyjson`) — fast JSON for Schema.org/JSON-LD spoke output
