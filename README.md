# Ontology

A Swift library for structured, narrative-friendly data exchange. Provides JSON-LD serializable entity types, a markdown-based persistence format, and bidirectional bridges to Apple frameworks (EventKit, Contacts, CoreLocation) and Google Workspace APIs (Calendar, People, Tasks, Drive).

## Requirements

- Swift 6.0+ / Xcode 16+
- macOS 14.0+ (Sonoma) · iOS 17.0+

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/wildthink/Ontology.git", branch: "main")
]
```

Add the products you need:

| Product | What it adds |
|---|---|
| `Ontology` | Pure hub — no platform dependencies |
| `OntologyApple` | EventKit, Contacts, CoreLocation, WeatherKit bridges |
| `OntologyGoogle` | Google Calendar, People, Tasks, Drive bridges |
| `OntologyOKF` | Markdown/YAML file read-write (OKF bundle format) |
| `Presentation` | SwiftUI views (depends on OntologyApple) |

---

## Core types

### Planning domain

| Type | What it represents | Standalone file? |
|---|---|---|
| `Plan` | Intent or template — owns commitments, tasks, schedule slots, alarms | Yes |
| `Occurrence` | Atomic space-time fact: a single time + place + description | Yes |
| `Task` | Actionable work unit belonging to a Plan | Yes |
| `Commitment` | Relational promise or obligation between actors within a Plan | Yes |
| `Record` | Documented outcome: what actually happened | Yes |

The lifecycle flows: **Opportunity → Plan → Commitments / Tasks / Schedule → Completion → Record**.

**Plan vs Occurrence** — the key distinction:
- `Plan` = intent (may have an `rrule` and generate recurring Occurrences)
- `Occurrence` = a specific time+place fact, optionally linked back to a Plan via `occurrence.plan`

An **Opportunity** is a `Plan` with `status: Plan.Status.opportunity` and a `subject` ref pointing to a seed Occurrence. No separate type needed.

A **ScheduleItem** is an `Occurrence` with `plan` set. No separate type needed.

**Alarms serve a plan but do not gate its completion.** Plans, Occurrences, and Tasks all carry `alarms: [Alarm]?`. These trigger notifications; they have no effect on `status`.

### Identity and reference types

| Type | Role |
|---|---|
| `Person` | A person with narrative, relationships, contact info |
| `Organization` | A group or institution |
| `Place` | A named location |
| `Collection` | Logical grouping of `HolonRef`s; declared in `_index.md` |
| `HolonRef` | Reference — `.entity(Taxon, String)` for entities, `.path(String)` for assets |
| `Taxon` | String-backed entity kind tag (`.person`, `.plan`, `.task`, etc.) |

### Value types (no independent identity)

| Type | Role |
|---|---|
| `DateTime` | `Date` + optional `TimeZone` |
| `GeoCoordinates` | Latitude, longitude, elevation |
| `QuantitativeValue` | Numeric value + UN/CEFACT unit code (e.g. `HUR` for hours) |
| `Alarm` | Trigger (offset minutes or absolute date) + delivery method |
| `PostalAddress` | Structured postal address |

---

## Plan — full field reference

```swift
var plan = Plan(
    identifier: "plan.abc123",      // taxon.shortHash — stable across renames
    name: "Session 12 preparation",
    description: "Detailed notes…",
    status: Plan.Status.active,     // see vocabulary below
    startDate: DateTime(…),         // when a scheduled block begins
    endDate:   DateTime(…),
    dueDate:   DateTime(…),         // target completion date (goal semantics)
    location:  place,
    url:       url,
    rrule:     "FREQ=WEEKLY;BYDAY=FR",  // RFC 5545, generates Occurrences
    tags:      ["session", "prep"],
    owner:     .entity(.person, "person.gm01"),
    participants: [.entity(.person, "person.player01")],
    subject:   .entity(.occurrence, "occurrence.seed01"),  // opportunity seed
    effort:    QuantitativeValue(value: 3, unitCode: "HUR", unitText: "hours"),
    alarms:    [.minutesBefore(60), .minutesBefore(15, method: "email")]
)
```

**Status vocabulary** (`Plan.Status`):

| Constant | String |
|---|---|
| `.opportunity` | `"opportunity"` |
| `.planning` | `"planning"` |
| `.active` | `"active"` |
| `.completed` | `"completed"` |
| `.cancelled` | `"cancelled"` |
| `.onHold` | `"on-hold"` |

**Grouping** — collect a plan's tasks and commitments into a `Collection`:

```swift
let col = plan.collection(members: [taskRef, commitmentRef])
// col.identifier = "collection.plan.<plan-id>"
```

---

## Task

```swift
let task = Task(
    identifier: "task.abc123",
    name: "Print character sheets",
    description: "Two copies per player",
    plan:     .entity(.plan, "plan.001"),
    assignee: .entity(.person, "person.gm01"),
    dueDate:  DateTime(…),
    status:   .open,            // .open | .inProgress | .done | .cancelled
    priority: 1,                // lower = higher priority
    alarms:   [.minutesBefore(120)]
)
```

Status defaults to `.open` on decode when the key is absent.

---

## Commitment

```swift
let invite = Commitment(
    identifier: "commitment.abc123",
    name: "GM invites player to session",
    plan:      .entity(.plan, "plan.001"),
    actor:     .entity(.person, "person.gm01"),
    recipient: .entity(.person, "person.player01"),  // nil = self-commitment
    role:      Commitment.Role.invitation,
    status:    Commitment.Status.pending,
    dueDate:   DateTime(…),
    note:      "Please RSVP by Friday"
)
```

**Role vocabulary** (`Commitment.Role`): `.invitation`, `.acceptance`, `.delegation`, `.acknowledgement`, `.selfCommitment`

**Status vocabulary** (`Commitment.Status`): `.pending`, `.accepted`, `.declined`, `.completed`, `.cancelled`

---

## Alarm

```swift
// Relative trigger — negative = before start
let a1 = Alarm.minutesBefore(15)              // 15 min before, "display" method
let a2 = Alarm.minutesBefore(60, method: "email")

// Absolute trigger
let a3 = Alarm.at(DateTime(someDate), method: "email")
```

`Alarm.method` values: `"display"` (popup), `"email"`, `"audio"`.

---

## Markdown exchange format

One file per entity; YAML frontmatter + markdown body:

```markdown
---
taxon: plan
id: plan.3f8a91b2
name: Session 12 preparation
status: active
dueDate: "2024-06-15T00:00:00Z"
owner: "[[person.gm01]]"
alarms:
  - method: display
    offsetMinutes: -60
---

## Notes

First planning meeting confirmed for Tuesday.
```

**Reading:**

```swift
import OntologyOKF

let doc = try OKFDocument(contentsOf: url)
let plan = try OKFReader.decode(Plan.self, from: doc.string())
```

**Writing:**

```swift
let doc = try OKFDocument(plan, body: "## Notes\n\n…")
try doc.write(to: url)
```

WikiLinks `[[taxon.id]]` are parsed into `HolonRef.entity` values and available via `MarkdownDocument.wikilinks`.

---

## Apple bridges (OntologyApple)

All bridges are bidirectional. The **read direction** takes the Apple type as an argument; the **write direction** gives you an `apply(to:)` mutating method plus a `make…(in:)` factory.

| Hub type | Apple type | Direction |
|---|---|---|
| `Occurrence` | `EKEvent` | `Occurrence(ekEvent)` · `occ.apply(to: event)` · `occ.makeEKEvent(in:)` |
| `Plan` | `EKReminder` | `Plan(reminder)` · `plan.apply(to: reminder)` · `plan.makeEKReminder(in:list:)` |
| `Task` | `EKReminder` | `Task(reminder)` · `task.apply(to: reminder)` · `task.makeEKReminder(in:list:)` |
| `Person` | `CNContact` | `Person(contact)` · `person.makeCNContact()` |
| `Place` | `CLPlacemark` | `Place(placemark)` (read only) |
| `Alarm` | `EKAlarm` | `Alarm(ekAlarm)` · `alarm.ekAlarm()` |

`Plan.startDate` = when a calendar block begins. `Plan.dueDate` maps to `EKReminder.dueDateComponents`.

---

## Google Workspace bridges (OntologyGoogle)

All Google types are `Codable` — decode straight from the API JSON response, encode for insert/update requests.

| Hub type | Google type | Read | Write |
|---|---|---|---|
| `Occurrence` | `GCalEvent` | `Occurrence(gcalEvent)` | `GCalEvent(occurrence)` |
| `Plan` | `GCalEvent` | `Plan(gcalEvent)` | `GCalEvent(plan)` |
| `Plan` | `GTask` | `Plan(gTask)` | `GTask(plan)` |
| `Task` | `GTask` | `Task(gTask)` | `GTask(task)` |
| `Person` | `GPerson` | `Person(gPerson)` | `GPerson(person)` |
| `Collection` | `GCalCalendar` | `Collection(gcalCalendar)` | — |
| `Record` | `GDriveFile` | `Record(gDriveFile)` | — |

**Alarm mapping:** Google stores positive minutes-before; the hub stores negative `offsetMinutes` (negative = before start). Absolute-date alarms fall back to 15-minute popup when writing to Google (API limitation).

**Status mapping:** `Occurrence.normalizedStatus(_:)` maps Google/Apple status strings to Schema.org EventStatus vocabulary (`"EventScheduled"`, `"EventCancelled"`, `"EventPostponed"`).

```swift
// Decode a Calendar API response
let events = try JSONDecoder().decode(GCalEventList.self, from: apiResponseData)
let occurrences = events.items?.map { Occurrence($0) } ?? []

// Build a request body from a hub Occurrence
let body = GCalEvent(occurrence)
let requestData = try JSONEncoder().encode(body)
```

---

## JSON-LD encoding

All hub types encode with `@context`, `@type`, and `@id` at the root. Nested value types omit `@context`:

```json
{
  "@context": "https://schema.org",
  "@type": "Plan",
  "@id": "plan.3f8a91b2",
  "name": "Session 12 preparation",
  "status": "active",
  "effort": {
    "@type": "QuantitativeValue",
    "value": 3,
    "unitCode": "HUR",
    "unitText": "hours"
  }
}
```

`@type` is validated with `decodeIfPresent` — absent in YAML frontmatter, present in JSON-LD. Both are valid inputs.

---

## DateTime encoding

```swift
let encoder = JSONEncoder()
// Priority: (1) userInfo override, (2) DateTime's own timeZone, (3) GMT
encoder.userInfo[DateTime.timeZoneOverrideKey] = TimeZone.current
```

---

## Deprecated types

`Event`, `PlanAction`, `ItemList`, `Trip` remain in the codebase marked `@available(*, deprecated)`. Use `Plan`, `Occurrence`, `Task`, and `Collection` for all new code.

---

## License

MIT. See LICENSE.md.

Apple Weather and Weather are trademarks of Apple Inc. This project is not affiliated with Apple Inc.
