# Agent Specification: Commitment-Centric Personal Planning

## Purpose

Implement the core domain model and workflow for a personal planning application where a user:

- discovers events and availabilities from subscribed people/org calendars
- selects an event-of-interest or creates a goal
- creates a plan from that seed
- estimates time, effort, and schedule
- works solo or invites others to collaborate
- associates reminders, appointments, and tasks with the plan
- executes work and marks the plan accomplished
- records progress in log or journal - includes activities, occurrences and/or results in execution of the plan

The system should treat plans as the primary user-facing object, with commitments, tasks, schedule items, reminders, and collaboration as supporting structures.

---

## Product Model

### Key idea

Do **not** model the app primarily as disconnected:
- calendar events
- todos
- reminders
- invitations

Instead, model it as:

**Opportunity → Plan → Commitments → Schedule/Tasks/Reminders → Completion**

---

## Core Concepts

### Opportunity
A discovered or created possibility that may seed a plan.

Examples:
- external event from subscribed calendar
- friend availability window
- organization event
- self-created goal or aspiration

### Plan
The main user-owned coordination object.

A plan may be:
- solo
- shared socially
- collaborative

A plan groups:
- origin opportunity or self-created goal
- commitments
- tasks
- schedule items
- reminders
- participants
- decisions
- progress

### Commitment
A relational promise or obligation between actors.

Use this to model:
- self-commitment
- invitation
- acceptance
- delegation
- collaboration
- completion acknowledgement

### Task
An actionable unit of work inside a plan.

### ScheduleItem
A projection of the plan into time.

Examples:
- calendar event
- focused work block
- appointment
- milestone block

### Reminder
A prompt associated with a plan, task, or schedule item.

### Participant
A person or organization involved in a plan.

---

## Required User Flow

### 1. Discovery
The user can subscribe to other people’s and organizations’ calendars.

The app should ingest and expose:
- events
- availabilities
- invitations
- candidate opportunities

### 2. Selection / Creation
The user can:
- select an existing opportunity
- create a goal manually

This creates a `Plan` seed.

### 3. Planning
The user can define:
- title
- purpose
- desired outcome
- estimated effort
- estimated duration
- deadline
- constraints
- notes

### 4. Collaboration
The user can:
- keep the plan solo
- invite friends
- share the plan
- assign tasks or commitments

### 5. Scheduling
The user can associate:
- schedule blocks
- appointments
- external calendar events
- reminders

### 6. Execution
The user can:
- make decisions
- add/update tasks
- track progress
- mark tasks complete
- mark commitments complete

### 7. Completion
The user can mark the plan accomplished.

If collaborative, support acknowledgement by others.

---

## Architecture Requirements

### Primary object
The primary top-level object must be `Plan`.

### Secondary objects
All of the following must attach to a `Plan`:
- commitments
- tasks
- schedule items
- reminders
- participants
- decisions
- notes

### Derived behavior
Calendar events and reminders should be treated as operational projections of a plan, not the root domain object.

---

## Domain Model

## `Plan`

```swift
struct Plan: Identifiable, Codable, Hashable {
    var id: ID
    var ownerID: ID?
    var title: String
    var summary: String?
    var dueDate: Date?
    var participantIDs: [UUID]
    var attachments: []
    var log: []
    var metadata: [String: String]
}