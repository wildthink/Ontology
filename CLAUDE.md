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

CI runs `swift build -v` and `swift test -v`. The package requires swift-tools 6.3 and macOS 26 (matching the downstream Luxo package, which depends on this one).

## Architectural direction

The codebase follows a **hub-and-spoke** architecture.

### Hub: this package's own ontology

**This package's types are the hub.** Schema.org, Apple frameworks, Google Workspace, OKF, JSON-LD, and the Luxo search package (`~/dev/packages/Luxo`, depends on this package by path) are all spokes. Where field names happen to align with Schema.org (e.g. `givenName`, `startDate`), that's a convenience — not a commitment. When the ontology's semantics diverge from Schema.org, the ontology wins.

### Holon + Entity

Every meaningful concept is a **Holon** — simultaneously a whole thing in itself, made of parts, and part of something larger. **Entity** is a Holon with typed, machine-readable attributes (`Codable`). Concrete types like `Person`, `Place`, `Organization`, `Plan`, `Occurrence`, `Task`, `Commitment` conform to `Entity`.

The `Entity` protocol requires two things beyond `Holon + Codable`:
- `var name: String? { get }` — every entity is displayable by name.
- `var meta: Meta? { get set }` — the open, schema-free metadata bag (`Meta = [String: Universal.JSON]`, see `Entities/Meta.swift`). `meta` round-trips through a nested `meta:` frontmatter key and never collides with typed schema fields. Spokes use it for provider extras (`kMDItem*` values, OpenGraph tags, raw JSON-LD, provenance).

`EntityReference` is `Identifiable` (usable directly in SwiftUI lists).

**Value types** (`DateTime`, `GeoCoordinates`, `QuantitativeValue`, `Alarm`) have no independent identity and live embedded in an Entity's fields.

### Core type vocabulary

| Type | What it is | Standalone file? |
|---|---|---|
| `Plan` | Intent or template; may carry an RRule and generate Occurrences via `occurrences(limit:)` | Yes |
| `Occurrence` | Atomic space-time fact: a single specific time + place + description | Yes |
| `Task` | Actionable work unit owned by a Plan | Yes |
| `Commitment` | Relational promise or obligation between actors within a Plan | Yes |
| `Record` | Documented outcome: a Plan or Occurrence + what actually happened | Yes |
| `Person` | A person with identity, narrative, relationships | Yes |
| `Organization` | A group, faction, institution | Yes |
| `Place` | A named location with description | Yes |
| `Collection` | A logical grouping of HolonRefs | Yes (`_index.md`) |
| `Outline` | A hierarchical catalog/table of contents: an ordered tree of `OutlineNode`s | Yes |
| `Topic` | A subject/theme with its own identity, referenced from other entities | Yes |
| `Relationship` | Standing social structure between two actors (rivalry, mentorship, membership) — independent of any Plan, unlike `Commitment` | Yes |
| `Artifact` | An in-fiction object with identity — a prop, weapon, document, possession | Yes |
| `Media` | A reference to an external/local image, video, or audio file, with caption/credit/format metadata. Not an in-fiction object — see `Artifact` | Yes |
| `Document` | A file, application, or web resource discovered by search — url + contentType + dates + size, everything else in `meta`. The flexible catch-all for Spotlight hits and unmapped web records. Distinct from `Media` (illustrative asset) and `Artifact` (in-fiction object) | Yes |
| `RRule` | Recurrence pattern — embedded inside a `Plan`, never standalone | No |
| `Schedule` | schema.org-shaped *view* onto a `Plan`'s recurrence. A value type, not storage — `Plan.rrule` stays canonical | No |
| `Alarm` | Notification trigger embedded in Plan/Occurrence/Task | No |
| `OutlineNode` | A node in an `Outline` — title + optional `HolonRef` + note/tags + children | No |
| `DateTime`, `GeoCoordinates`, `QuantitativeValue` | Value types embedded in parent frontmatter | No |
| Weather types | Transient sensor data, no narrative | No |

**Plan vs Occurrence** — do not conflate them:
- `Plan` = intent (may have `rrule`, generates Occurrences)
- `Occurrence` = atomic space-time fact

**Opportunity pattern**: `Plan` with `status: "opportunity"` and `subject: HolonRef` pointing to a seed Occurrence. No separate type.

**ScheduleItem pattern**: `Occurrence` with `plan: HolonRef` set. No separate type.

**Alarms are informational** — they may be set on Plans, Occurrences, and Tasks to trigger notifications, but plan progress and completion must never depend on them.

The deprecated `Event`, `PlanAction`, `ItemList`, and `Trip` types have been **removed**. Use `Plan`/`Occurrence`/`Collection`.

### Markdown as exchange format

The canonical persistence and exchange format is **one markdown file per Entity**. Files use YAML frontmatter for machine-readable fields and a markdown body for free-form narrative.

```markdown
---
taxon: plan
id: plan.3f8a91b2
name: Session prep
status: active
alarms:
  - method: display
    offsetMinutes: -60
---

First planning meeting confirmed.
```

Frontmatter keys are this ontology's field names. The `taxon` key replaces `@type`; `id` replaces `@id`; `@context` is omitted.

**Reading:** `MarkdownDocument(string:)` / `MarkdownDocument(contentsOf:)` splits the fence, then `FrontmatterParser.decode(_:from:)` runs YAML → JSON → `Decodable` via `universal`.

**Writing:** `MarkdownDocument(_ entity:, body:)` encodes via `JSONEncoder`, normalises keys, serialises to YAML, then `MarkdownDocument.write(to:)` writes atomically.

**YAML serialization rule:** `@type` is written when encoding but validated with `decodeIfPresent` when decoding — frontmatter never has `@type`. Types get this by calling `encodeJSONLDHeader` / `decodeJSONLDHeader` rather than hand-writing it; see [JSON-LD encoding pattern](#json-ld-encoding-pattern).

### HolonRef — two reference modes

```swift
public enum HolonRef: Hashable, Codable, Sendable {
    case entity(Taxon, String)   // [[person.3f8a91b2]] — stable across renames
    case path(String)            // ./assets/portrait.jpg — for assets (images, PDFs)
}
```

Use `.entity` for semantic entity references. Use `.path` for binary assets. WikiLink syntax `[[taxon.id]]` is parsed by `WikiLinkScanner` into `HolonRef.entity` values.

### Taxon constants

All static Taxon constants are declared in `Taxon.swift`. Current set:

```swift
.anything, .agent, .person, .org, .place, .event, .topic,
.plan, .occurrence, .record, .collection, .task, .commitment, .outline,
.relationship, .artifact, .media, .document, .tool, .frame
```

### Module structure

```
Sources/
  Ontology/           # Hub — pure Swift, Foundation only
    Types/            # Person, Place, Organization, Plan, Occurrence, Record,
                      #   Task, Commitment, Collection, Alarm, QuantitativeValue,
                      #   Schedule, Plan+Schedule (schedule view + generation), …
    Entities/         # Holon, Entity, HolonRef, Taxon, Identifiers
    Markdown/         # MarkdownDocument, FrontmatterParser, WikiLinkScanner,
                      #   MarkdownWriter, YAMLSerializer
    Extensions/       # RecurrenceRuleRFC5545FormatStyle (vendored, MIT),
                      #   RFC5545DateList (EXDATE/RDATE lines)
    JSON-LD.swift     # JSONLDCodingKey, header helpers, lenient decode helpers
    Schema.swift      # schema.org constant

  OntologyApple/      # Spoke — all #if canImport blocks live here
    AlarmBridge       # Alarm ↔ EKAlarm
    EventBridge       # Occurrence ↔ EKEvent (canonical)
    PlanBridge        # Plan ↔ EKReminder
    TaskBridge        # Task ↔ EKReminder
    PersonBridge      # Person ↔ CNContact
    PlaceBridge       # CLPlacemark → Place
    WeatherBridge     # WeatherKit → WeatherConditions / WeatherForecast
    …

  OntologyGoogle/     # Spoke — Google Workspace API types + bridges
    GCalEvent         # GCalEvent ↔ Occurrence / Plan (bidirectional)
    GCalCalendar      # GCalCalendar → Collection (read only)
    GPerson           # GPerson ↔ Person (bidirectional)
    GTask             # GTask ↔ Task / Plan (bidirectional)
    GDriveFile        # GDriveFile → Record (read only)

  OntologyOKF/        # Spoke — markdown bundle read/write
    OKFBundle, OKFDocument, OKFReader

  Presentation/       # SwiftUI views (depends on OntologyApple)
```

`OntologyApple.swift` re-exports `Ontology` via `@_exported import Ontology`.

### All SchemaEntityReference + Entity conformances live in Identifiers.swift

Do not add `SchemaEntityReference` or `Entity` conformances inside type files. All conformances for hub types belong in `Sources/Ontology/Entities/Identifiers.swift`. Deprecated type conformances go at the bottom of that file, marked `@available(*, deprecated)`.

### Adding a new type — follow this order

**Step 0 is the one that matters.** Getting Entity-vs-value wrong costs a rewrite; everything after it is mechanical.

#### 0. Entity or value type?

| | Entity | Value type |
|---|---|---|
| Has independent identity | yes | no |
| Own `.md` file | yes | no — embedded in a parent's frontmatter |
| Needs a `Taxon` | yes | no |
| Conformances in `Identifiers.swift` | yes | no |
| Examples | `Person`, `Plan`, `Document` | `Alarm`, `Schedule`, `QuantitativeValue` |

The test: **would anything ever link to it with `[[taxon.id]]`?** If no, it's a value type. Two more signals — if it only ever appears as a field of something else (schema.org `Intangible` subtypes usually do), it's a value type; if it duplicates information another type already stores, prefer a *view* over that storage rather than a second source of truth (see `Plan.schedule` over `Plan.rrule`).

Before adding an Entity, check whether an existing type plus a status or field already covers it — `Opportunity` and `ScheduleItem` are patterns over `Plan`/`Occurrence`, not types. The hub is deliberately small.

#### 1. Write the type — `Sources/Ontology/Types/<Name>.swift`

```swift
public struct Thing: Hashable, Sendable {
    public var identifier: String?      // Entity only
    public var name: String?            // Entity only — the Entity protocol requires it
    // … fields, all `var`, all optional unless genuinely required
    public var meta: Meta?              // Entity only — the open metadata bag

    public init(identifier: String? = nil, /* … */) { /* … */ }
}
```

Every parameter gets a default so callers name only what they set. Fields are `var` — bridges mutate in place.

#### 2. Codable — use the header helpers, never hand-roll

```swift
extension Thing: Codable {
    private enum CodingKeys: String, CodingKey { case name, /* … */ }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        try c.encodeJSONLDHeader(Self.self, id: identifier, encoder: encoder)   // omit `id:` for value types
        try c.encodeIfPresent(name, forKey: .attribute(.name))
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
        identifier = try c.decodeJSONLDHeader(Self.self)                        // `_ = try …` for value types
        name = try c.decodeIfPresent(String.self, forKey: .attribute(.name))
    }
}
```

Use `decodeIfPresent` for every optional field. Reach for the lenient helpers (`decodeFlexibleStringList`, `decodeFlexibleIntList`, `decodeStringLeniently`) on any field that arrives from wild-web JSON-LD — scalars-where-arrays-belong and numbers-where-strings-belong are the norm, not the exception.

#### 3. Entity only — register identity in two places

- `Taxon.swift`: add the `static let` constant.
- `Identifiers.swift`: add `SchemaEntityReference` + `Entity` conformances. **Not in the type file.**

#### 4. Wire up the spokes that need it

- Appears in wild JSON-LD? Add it to `SchemaTypeRegistry.decoders`, and add a `stamped` case so it gets a minted id and a source handle.
- Has an Apple/Google counterpart? Follow the [bidirectional bridging pattern](#bidirectional-bridging-pattern) — the bridge lives in the spoke module, never in `Ontology`.

#### 5. Test it

At minimum: a JSON round trip, a **markdown frontmatter round trip** (this is the canonical format — `MarkdownDocument(thing)` → `.string()` → `decode`), an `@type`-mismatch rejection, and the wild-web shapes you expect. Assert `!text.contains("@type")` on frontmatter output.

#### 6. Update this file

Add a row to the [core type vocabulary](#core-type-vocabulary) table, including the standalone-file column. If the type deviates from any rule here, say so and say why — an undocumented deviation reads as drift and the next agent will "fix" it.

### Bidirectional bridging pattern

All bridges follow this convention:

- **Read direction** (foreign → hub): `HubType.init(_ foreign:)` — a regular or failable init, defined in the spoke module.
- **Write direction** (hub → foreign): Three entry points, all in the spoke module:
  - `ForeignType.init(_ hub:)` — constructs a fresh foreign value from a hub type
  - `hub.apply(to: foreign)` — updates an existing foreign object in place; returns `Bool` (true if changes were made)
  - `hub.makeForeign(in:)` — factory that creates, configures, and returns a new foreign object (EventKit style)

Google types that are metadata sources without a write path (Calendar list, Drive file) are read-only (`GCalCalendar`, `GDriveFile`).

### Google alarm sign convention

Google Calendar stores positive minutes-before (e.g., `10` = 10 minutes before). The hub stores negative `offsetMinutes` (e.g., `-10` = 10 minutes before). Conversion: `hub.offsetMinutes = -(gcal.minutes ?? 15)`. Absolute-date alarms fall back to 15-minute popup when writing to Google (API limitation).

### Entity identity

`Taxon` is a string-backed value type (`ExpressibleByStringLiteral`, `CustomStringConvertible`). Entity IDs take the form `taxon.shortHash` (e.g. `person.3f8a91b2`) — stable across file renames. `EntityReference.shortID(taxon:)` generates them.

### JSON-LD encoding pattern

All hub types use `JSONLDCodingKey<CodingKeys>` for their `Codable` conformance:

- `.context` → `"@context"` (only at root: `encoder.codingPath.isEmpty`)
- `.type` → `"@type"` (always; value is `String(describing: Self.self)`)
- `.id` → `"@id"` (for `identifier`)
- `.attribute(.name)` → `"name"` (for all other fields)

**Write the header with the helpers, not by hand.** `JSON-LD.swift` provides two container extensions that are the single enforcement point for the three framing keys:

```swift
try container.encodeJSONLDHeader(Self.self, id: identifier, encoder: encoder)  // @context/@type/@id
identifier = try container.decodeJSONLDHeader(Self.self)                       // validates @type, returns @id
```

Value types with no identity omit the `id:` argument and discard the result (`_ = try container.decodeJSONLDHeader(Self.self)`).

`decodeJSONLDHeader` performs the `decodeIfPresent` validation that keeps frontmatter YAML (which never has `@type`) decodable: an *absent* `@type` always passes, a *present and mismatched* one throws. Hand-rolling this is what let the rule drift — before the helpers existed, 10 of 22 types encoded `@type` and never validated it on decode.

**Deliberate opt-outs** — three types do not use the helpers, and should not be "fixed" to match:

| Type | Why |
|---|---|
| `DateTime` | Encodes as a bare ISO 8601 string when nested; only emits a JSON-LD header at root. |
| `WeatherConditions`, `WeatherForecast` | `@type` is a WeatherKit URL, not the Swift type name, and decode is strict (`decode`, not `decodeIfPresent`). Safe because weather is transient sensor data that never round-trips through frontmatter. |

### DateTime encoding

`DateTime` wraps `Date` + optional `TimeZone`. Timezone resolution priority during encoding: (1) `encoder.userInfo[DateTime.timeZoneOverrideKey]`, (2) the `DateTime`'s own `timeZone`, (3) GMT/UTC.

`DateTime(string:)` parses **leniently**: fractional seconds, whole seconds, or a bare date (`2026-06-30`) all accept — wild-web JSON-LD and hand-authored frontmatter rarely include fractional seconds.

### SchemaTypeRegistry (wild-web JSON-LD → hub entities)

`SchemaTypeRegistry.entity(fromJSONLD:sourceURL:)` decodes schema.org JSON-LD records into hub entities: `Person`→`Person`, `Organization` subtypes→`Organization`, `Place`/`LocalBusiness`→`Place`, `Event` subtypes→`Occurrence`, everything else (or any typed-decode failure) → `Document` preserving the raw record in `meta["jsonld"]`. Never throws.

Leniency machinery for wild data (do not remove):
- `@type` is stripped **recursively** before decode (nested schema.org type names never match hub Swift type names).
- schema.org Event `location` objects are remapped to `Occurrence.place` (`normalizedEventObject`).
- `KeyedDecodingContainer.decodeFlexibleStringList(forKey:)` accepts `String` or `[String]` for repeatable properties (Person.email/telephone/url/sameAs/knowsLanguage use it). `decodeFlexibleIntList(forKey:)` is the numeric equivalent (Schedule.byMonth/byMonthDay/byMonthWeek), and also accepts digits written as strings.
- Entities decoded from records without `@id` get a minted `shortID` so search UIs always have distinct stable ids.
- **An `Event` carrying `eventSchedule` decodes to `Plan`, not `Occurrence`** (`normalizedScheduledEvent`). A recurring event is intent that generates instances; `Occurrence` is an atomic space-time fact and has no `rrule` field, so routing these to `Occurrence` would silently drop the recurrence. The schedule's `startDate` seeds the plan's, and `exceptDate` becomes `exceptDates`. When the schedule yields no usable rule — or there is more than one — the raw record is preserved in `meta["eventSchedule"]`.

### Recurrence rules

`RecurrenceRuleRFC5545FormatStyle` implements `FormatStyle` / `ParseStrategy` for `Calendar.RecurrenceRule` ↔ RFC 5545 RRULE strings. Vendored from RRuleKit (MIT). The `Plan.rrule` field stores the RFC 5545 string directly (not a parsed `Calendar.RecurrenceRule`).

**Go through this format style** for any RRULE string work — it already handles `BYDAY` ordinal encoding (`-1SU`, `2FR`), `UNTIL` formatting, list joining, and frequency names in both directions. `Schedule` converts by building a `Calendar.RecurrenceRule` and formatting it, never by assembling RRULE strings by hand.

`Schedule` (schema.org) ↔ `rrule` is lossy by design. Only `repeatFrequency`, `repeatCount`, `endDate`, `byDay`, `byMonth`, and `byMonthDay` have clean RFC 5545 equivalents. `byMonthWeek`, `startTime`, `endTime`, and `duration` are carried on the value but do not participate in the rule — `byMonthWeek` is week-of-*month* and has no counterpart (`BYWEEKNO` is week-of-*year*, and would be wrong). See the table in `Schedule.swift`.

`Plan.exceptDates` holds RFC 5545 `EXDATE` — cancelled instances of a recurring plan. `EXDATE` lives on its own content line rather than inside the RRULE, so it is **not** covered by the format style; `RFC5545DateList` (in `Extensions/`) parses and formats it, handling the UTC, `TZID=`, and date-only value forms. Google's `recurrence` array carries `RRULE:` and `EXDATE:` as separate entries and both directions of `GCalEvent` handle them.

`Plan.occurrences(limit:from:calendar:)` generates `Occurrence` values from the plan's recurrence, honouring `exceptDates` and back-referencing the plan (the ScheduleItem pattern). `limit` is required — an `rrule` without `COUNT` or `UNTIL` recurs forever. Generation needs an anchor: `from`, else `startDate`, else `dueDate`. Results are not persisted and carry no identifier.

### YAMLSerializer array-of-objects rule

When serializing arrays of objects in YAML, the first key of each object item goes on the same line as the `- ` sequence indicator. Subsequent keys in the same item use `pad + "  "` (continuation indent). This is what `YAMLSerializer.array()` implements. Do not revert to the simpler `"\(pad)- \(serialize($0, indent: indent + 1))"` pattern — it produces over-indented YAML that breaks the `universal` parser when scalar keys follow the array in the same document.

### Plan.dueDate vs Plan.startDate

- `startDate` = when a scheduled time block begins (calendar semantics)
- `dueDate` = target completion date (goal semantics)

`EKReminder.dueDateComponents` maps to `Plan.dueDate` (not `startDate`). `Plan.apply(to reminder:)` uses `dueDate ?? startDate` as a fallback.

### Dependencies

- **universal** (`marcprux/universal`, branch: main) — zero-dep YAML/JSON/XML/PLIST parser; used for frontmatter parsing (YAML → JSON → `Decodable`)
- **Period** — date period/range types
- **YYJSON** (`swift-yyjson`) — fast JSON for Schema.org/JSON-LD spoke output
