# Agent Specification: Plan-Centric Personal Planning

## Purpose

Define the domain model for a personal planning application where a user:

- discovers events and openings from subscribed people/org calendars
- selects an event-of-interest or states a goal
- creates a plan from that seed
- breaks the plan into action-items, estimating time and effort
- works solo or invites others along
- optionally hangs reminders, alarms, and calendar events off the plan to help coordinate
- works the list and marks the plan accomplished
- **keeps a durable record of what actually happened**

A **Plan is an enhanced checklist** that participants work through. Everything else —
reminders, alarms, calendar events, formal commitments — is optional scaffolding that
may support coordination but is never required for a plan to be planned, worked, or
finished.

### The record is the point

A reminder falls off the list when it's done. A calendar event scrolls into the past.
Neither remembers anything. This app is built on the opposite premise: **the user should
be able to look back and know what they did.** That memory lives in `Record` and in the
`Occurrence` values a plan generates — not in the transient prompts that helped along the
way.

---

## Product Model

### Key idea

Do **not** model the app as a pile of disconnected:

- calendar events
- action-items
- reminders
- invitations

Model it as:

**Opportunity → Plan → Action-Items → Doing → Record**

Calendar events and reminders are *operational projections* of a plan, not the root
domain object.

---

## Core Concepts

### Plan

The primary user-owned object — an enhanced checklist.

A plan may be solo, shared socially, or collaborative. It carries:

- an origin: a seed opportunity, or a self-stated goal
- action-items (the checklist itself)
- participants
- optional alarms
- notes / narrative body

Lifecycle via `status`: `opportunity` → `planning` → `active` → `completed` | `cancelled`,
with `on-hold` available for a pause.

### Action-Item

An actionable unit of work inside a plan — the check-off of an accomplishment by a single
participant. The type is `Task`; "action item" is the user-facing word for it.

- may have an associated reminder and/or calendar event, but needs neither
- attending a meeting or completing a reminder may itself *be* the action
- can carry an estimated time-to-complete
- can record who completed it, and when
- optional due date, or a relative scheduling intent (`asSoonAsPossible` / `soon` / `later`)
- **atomic to complete** — it is open, in-progress, done, skipped, or cancelled, and
  `status` alone says which. An item may also carry an optional count toward a goal
  (see [Progress](#progress)), but that is a note of what's up, never a second answer
  to "is this done?". No history of progress steps either way.
- can be skipped or cancelled; doing so clears it from the checklist and unblocks plan
  completion

### Record

The durable answer to "what did I do?"

A `Record` documents an outcome. Its `subject` points at the Plan or Occurrence it
describes, and `outcome` narrates what actually happened.

- one Record is written when a plan is completed
- additional Records may be written at any point for notable outcomes along the way
- Records are never deleted as a side effect of completing or clearing anything

Activities and attendances are recorded as `Occurrence` values back-referencing the plan.
Together, Occurrences (what happened, when) and Records (what came of it) are the journal.

### Progress

An optional count on an **action-item** — "3 of 10 pages", "8 of 10 miles".

- lives on the `Task`, as `goal` / `progress` / `unitLabel`. A plain check-off leaves
  `goal` nil, which is the common case.
- **advisory, never the truth about doneness.** `status` decides whether an item is
  done; progress is what participants can see along the way. Reaching the goal does not
  check the item off, and checking it off does not require reaching the goal.
- **mutated in place**. `advance(by:)` overwrites the value and moves the single
  `progressUpdatedAt` stamp. No entry history, no audit trail.

This was a separate `Score` type on `Plan.scoreCard` until UX testing found scores and
action-items pairing off one-to-one in practice — two objects, one concept, and friction
where they met. `Score` documented its own collapse: *"Boolean -> goal is 1."* A checkbox
was always a score with a goal of 1, so the count moved onto the item and the type went
away.

The remaining split is deliberate: **progress is a live gauge with no memory; the Record
is the memory.**

### Participant

A person or organization involved in a plan — `owner` plus `participants`.

### Optional supports

These exist to help people coordinate and remember. **None of them gate plan progress or
completion**, and a plan that uses none of them is complete and well-formed.

| Support | How it's modeled |
|---|---|
| Alarm / notification | `Alarm` embedded in a Plan, Occurrence, or Task |
| Calendar event, work block, appointment | an `Occurrence` whose `plan` back-references the Plan (the ScheduleItem pattern) |
| External reminder (Apple Reminders, Google Tasks) | a `Task` or `Plan` bridged out through the spoke modules; matched back by `handles` |
| Formal commitment | the `Commitment` type — available for genuine delegation or invitation, but **not part of the planner pipeline**. Between participants who understand each other, a commitment stays implicit; `Task.assignee` carries "who is doing what". |

### Patterns, not types

Two concepts in this spec are patterns over existing types rather than types of their own:

- **Opportunity** — a `Plan` with `status: "opportunity"` and `subject` pointing at the
  seed Occurrence.
- **ScheduleItem** — an `Occurrence` with `plan` set.

---

## User Flow

Steps 1 and 4 are **app-layer** — this package supplies the types they exchange, not the
integration. See [Out of scope](#out-of-scope).

### 1. Discovery *(app layer)*

The user subscribes to other people's and organizations' calendars. The app ingests and
exposes events and openings as candidate opportunities.

### 2. Selection / creation

The user selects a candidate, or states a goal. Either way this yields a `Plan` seed —
an opportunity-status Plan, or a fresh planning-status Plan.

### 3. Planning

The user defines: name, description, desired outcome, action-items, estimated effort,
estimated duration, due date, notes.

### 4. Collaboration *(app layer)*

The user keeps the plan solo, invites others, or shares it, and assigns action-items.

### 5. Scheduling *(optional)*

The user may attach work blocks, appointments, external calendar events, alarms, and
reminders. Skipping this step entirely is a supported way to use a plan.

### 6. Execution

The user works the list: adds and updates action-items, checks them off, skips what no
longer applies, and notes progress on anything counted.

### 7. Completion

The user marks the plan accomplished. A plan may be completed when no action-item is
still `open` or `inProgress` — clear stragglers by marking them done, skipped, or
cancelled. Progress counts and alarms never block completion.

### 8. Recording

Completion produces a `Record`. This is the step that distinguishes this app from a
reminder list, and it is not optional.

---

## Architecture Requirements

### Primary object

The primary top-level object is `Plan`.

### Attachment

These attach to a `Plan`:

- action-items (`Task.plan` back-reference), each carrying its own optional progress count
- participants
- notes
- optionally: alarms, and Occurrences via `Occurrence.plan`

### Derived behavior

Calendar events and reminders are operational projections of a plan, not roots. Bridging
them to Apple and Google systems is a spoke concern (`OntologyApple`, `OntologyGoogle`),
never part of the hub types.

---

## Domain Model

The shipped hub types are the specification. This section states only how they map to the
concepts above, and what is still missing.

| Concept | Type | Where |
|---|---|---|
| Plan | `Plan` | `Types/Plan/Plan.swift` |
| Action-Item | `Task` | `Types/Task.swift` |
| Record | `Record` | `Types/Record.swift` |
| Progress | `goal` / `progress` / `unitLabel` on `Task` | `Types/Task.swift` |
| ScheduleItem | `Occurrence` with `plan` set | `Types/Occurrence.swift` |
| Alarm | `Alarm` | `Types/Alarm.swift` |
| Participant | `Person` / `Organization`, referenced by `HolonRef` | `Types/` |
| Commitment *(optional)* | `Commitment` | `Types/Commitment.swift` |

### Schema delta

None. The code and this spec agree.

### What is deliberately absent

- no progress history anywhere — progress overwrites, Records accumulate
- no `log` array on `Plan` — that would reintroduce the history deleted with `Score.Entry`
- no separate score or gauge type — a count lives on the action-item it counts
- no plan-level progress value — a plan's progress is its checklist
- no `Opportunity` or `ScheduleItem` type — both are patterns
- no requirement that a plan have alarms, reminders, calendar events, or commitments

---

## Out of scope

This package is the domain hub. It supplies types and the markdown exchange format. The
following belong to the app or to spoke modules, and are named here only so the boundary
is explicit:

- calendar subscription, ingestion, and openings/availability discovery
- invitations, sharing, and collaborative acknowledgement transport
- notification delivery and scheduling
- persistence, sync, and conflict resolution
- all user interface
