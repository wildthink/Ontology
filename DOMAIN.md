# Domain Model

This document describes the conceptual model underlying the 
Ontology library — the vocabulary, relationships, and lifecycle it 
is designed to support. It is the reference for anyone building
applications on top of this package, and the source of truth when 
the code and this document conflict.

---

## The big idea

Most planning and coordination tools model the world as disconnected 
objects: calendar events, to-do items, reminders, invitations. 
This leads to friction — you create an event, then a separate 
task, then a separate reminder, and nothing knows they are all 
about the same thing.

This library models the world differently:

**Opportunity → Plan → Commitments / Tasks / Schedule → Completion → Record**

A `Plan` is the primary coordinating object. Everything else — 
schedule slots, tasks, reminders, collaborators, outcomes — 
attaches to it. Calendar events and reminders are projections of 
a plan into time, not the root domain object.

---

## Core concepts

### Plan

The main user-owned coordination object. A plan represents intent: something you are trying to accomplish. It may be solo, shared, or collaborative.

A plan holds:
- its purpose and desired outcome (`name`, `description`)
- estimated effort and deadline (`effort`, `dueDate`)
- who owns it and who is involved (`owner`, `participants`)
- how it originated (`subject` — points to a seed Opportunity)
- its current lifecycle stage (`status`)
- associated schedule blocks, tasks, commitments, and alarms

`Plan.status` moves through: `opportunity → planning → active → completed | cancelled | on-hold`

A plan with `rrule` set is a recurring template. Each scheduled instance is an `Occurrence` linked back to the plan.

### Occurrence

An atomic space-time fact: something that happens at a specific time in a specific place. An occurrence has no inherent goal or intent — it just records *what happened* or *what is scheduled to happen*.

When an Occurrence is linked to a Plan via `occurrence.plan`, it becomes a **schedule item** for that plan. There is no separate ScheduleItem type.

### Task

An actionable unit of work belonging to a Plan. Tasks have status (`open → inProgress → done | cancelled`), optional priority, optional assignee, and optional due date. They serve the plan but do not gate it: a plan can be marked `completed` regardless of task status.

### Commitment

A relational promise or obligation between actors within a Plan. Commitments model the social layer of coordination:

| Role | Meaning |
|---|---|
| `invitation` | Actor invites recipient to participate |
| `acceptance` | Recipient agrees to participate |
| `delegation` | Actor assigns responsibility to recipient |
| `acknowledgement` | Recipient confirms completion |
| `selfCommitment` | Actor commits to themselves (no recipient) |

Commitments move through: `pending → accepted | declined → completed | cancelled`

Like tasks, commitments serve a plan but do not gate its completion.

### Alarm

A notification trigger attached to a Plan, Occurrence, or Task. An alarm has:
- a **trigger**: either a negative minute offset (e.g. `-15` = 15 minutes before start) or an absolute date
- a **method**: `"display"` (popup), `"email"`, or `"audio"`

Alarms do not gate plan progress or completion. They are advisory.

### Record

A documented outcome: what actually happened as a result of executing a Plan or Occurrence. Records may carry a `url` pointing to an artifact (a Drive document, a journal entry, a log file).

### Opportunity

Not a separate type. An Opportunity is a `Plan` with `status: "opportunity"` and a `subject` reference pointing to a seed Occurrence (typically an external calendar event that caught the user's attention). When the user decides to act on the opportunity, they update the plan's status and flesh out the details.

---

## Reference types

### Person, Organization, Place

Identity entities. They exist independently of plans and can participate in many plans as owner, participant, or attendee.

### Collection

A named logical grouping of entity references. Collections live in `_index.md` files and declare membership independently of the directory layout — a Person in `people/jane.md` can be a member of a campaign collection without moving the file.

`Plan.collection(members:)` is a convenience that generates a Collection whose `identifier` is `"collection.plan.<plan-id>"`.

### HolonRef

The reference currency of the system. Two modes:
- `.entity(taxon, id)` — a stable cross-reference to another entity, written as `[[taxon.id]]` in markdown
- `.path(string)` — a relative path to a binary asset (image, PDF) co-located with files

Always use `.entity` for references between semantic entities. Path refs break when files move; entity refs do not.

---

## Lifecycle example

1. **Discovery**: User sees a regional LARP event on a subscribed calendar. It arrives as a `GCalEvent`, bridged to an `Occurrence`.

2. **Opportunity**: User creates a `Plan` with `status: "opportunity"` and `subject` pointing to that Occurrence.

3. **Planning**: User fleshes out the plan — sets a `dueDate`, adds `participants`, estimates `effort`. Status moves to `"planning"`.

4. **Collaboration**: User creates `Commitment`s — inviting two players, delegating a task to a co-GM.

5. **Scheduling**: User creates `Occurrence`s as schedule items (prep sessions, the event itself) and links them to the plan. Sets `Alarm`s on the plan and on key tasks.

6. **Execution**: Users mark `Task`s done, `Commitment`s accepted or completed.

7. **Completion**: Plan marked `"completed"`. A `Record` is created capturing the outcome, linked to a Drive doc with session notes.

---

## Field semantics that are easy to confuse

**`Plan.startDate` vs `Plan.dueDate`**
- `startDate` = when a scheduled block begins (calendar semantics — maps to EKEvent.startDate and GCalEvent.start)
- `dueDate` = target completion date (goal semantics — maps to EKReminder.dueDateComponents)

Both may be set simultaneously on the same plan.

**`Occurrence.status`**
Stored as a Schema.org EventStatus string: `"EventScheduled"`, `"EventCancelled"`, `"EventPostponed"`, `"EventRescheduled"`. `Occurrence.normalizedStatus(_:)` converts Apple/Google vocabulary to this form.

**`Alarm.trigger` sign convention**
Negative `offsetMinutes` = before start. `-15` means 15 minutes before. This matches EKAlarm's `relativeOffset` convention. Google Calendar uses positive minutes-before; the bridge negates automatically.

---

## External system mappings

| Hub type | Apple (EventKit) | Google Calendar | Google Tasks |
|---|---|---|---|
| `Plan` | `EKReminder` | recurring `GCalEvent` | `GTask` |
| `Occurrence` | `EKEvent` | `GCalEvent` (instance) | — |
| `Task` | `EKReminder` | — | `GTask` |
| `Person` | `CNContact` | `GPerson` | — |
| `Collection` | `EKCalendar` | `GCalCalendar` | — |
| `Record` | — | — | `GDriveFile` |
| `Alarm` | `EKAlarm` | `GCalEvent.Reminders.Override` | — |

All bridges are bidirectional except where noted. The hub type is always the authority; the external type is a projection.
