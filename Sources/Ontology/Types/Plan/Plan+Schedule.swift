import Foundation

// MARK: - Schedule view

extension Plan {
    /// This plan's recurrence expressed in schema.org terms.
    ///
    /// A *view*, not storage: reading builds a `Schedule` from `rrule`, `startDate`,
    /// and `exceptDates`; writing decomposes back into those fields. `rrule` stays
    /// the single source of truth, so there is nothing to keep in sync and existing
    /// frontmatter is unaffected.
    ///
    /// Fields with no RFC 5545 equivalent (`startTime`, `duration`, `byMonthWeek`)
    /// do not survive a set-then-get round trip — see `Schedule` for the table.
    ///
    /// - Important: assigning a `Schedule` whose `repeatFrequency` is missing or
    ///   unrecognised clears `rrule`, because there is no rule to store. A property
    ///   setter cannot report that, so check `Schedule.rrule()` first when the value
    ///   came from untrusted input:
    ///   ```swift
    ///   guard schedule.rrule() != nil else { /* handle unusable recurrence */ }
    ///   plan.schedule = schedule
    ///   ```
    public var schedule: Schedule? {
        get {
            guard let rrule, var schedule = Schedule(rrule: rrule) else { return nil }
            schedule.startDate = startDate
            schedule.exceptDate = exceptDates
            return schedule
        }
        set {
            rrule = newValue?.rrule()
            exceptDates = newValue?.exceptDate
            if let start = newValue?.startDate { startDate = start }
        }
    }
}

// MARK: - Occurrence generation

extension Plan {
    /// The dates this plan recurs on, honouring `exceptDates`.
    ///
    /// Returns an empty array when the plan has no `rrule` or no anchor date —
    /// a recurrence needs a first instance to count from. The anchor is
    /// `from` when given, otherwise `startDate`, otherwise `dueDate`.
    ///
    /// - Parameters:
    ///   - limit: maximum number of dates to generate. Required: an `rrule`
    ///     without `COUNT` or `UNTIL` recurs forever.
    ///   - from: anchor date, overriding the plan's own start.
    ///   - calendar: calendar used to interpret the rule.
    public func recurrenceDates(
        limit: Int,
        from: Date? = nil,
        calendar: Calendar = .current
    ) -> [Date] {
        guard limit > 0, let rrule else { return [] }
        guard let anchor = from ?? startDate?.value ?? dueDate?.value else { return [] }
        guard let rule = try? Calendar.RecurrenceRule(
            rrule, strategy: .rfc5545(calendar: calendar)
        ) else { return [] }

        // EXDATE matches to the second in RFC 5545; compare at that granularity
        // so a timezone-shifted DateTime still cancels the instance it names.
        let excluded = Set((exceptDates ?? []).map { $0.value.timeIntervalSinceReferenceDate.rounded() })

        var dates: [Date] = []
        for date in rule.recurrences(of: anchor) {
            guard dates.count < limit else { break }
            if excluded.contains(date.timeIntervalSinceReferenceDate.rounded()) { continue }
            dates.append(date)
        }
        return dates
    }

    /// Occurrences generated from this plan's recurrence.
    ///
    /// Each result is a `ScheduleItem` in the CLAUDE.md sense: an `Occurrence` whose
    /// `plan` back-references this plan. Name, description, and place are inherited;
    /// each occurrence's duration matches the plan's `startDate`→`endDate` span when
    /// both are set.
    ///
    /// Occurrences are generated, not persisted — they carry no identifier until a
    /// caller assigns one.
    public func occurrences(
        limit: Int,
        from: Date? = nil,
        calendar: Calendar = .current
    ) -> [Occurrence] {
        let span: TimeInterval? = {
            guard let start = startDate?.value, let end = endDate?.value, end > start
            else { return nil }
            return end.timeIntervalSince(start)
        }()
        let backRef = identifier.map { HolonRef.entity(Self.taxon, $0) }
        let zone = startDate?.timeZone

        return recurrenceDates(limit: limit, from: from, calendar: calendar).map { date in
            Occurrence(
                name: name,
                description: description,
                startDate: DateTime(date, timeZone: zone),
                endDate: span.map { DateTime(date.addingTimeInterval($0), timeZone: zone) },
                place: location,
                plan: backRef,
                alarms: alarms
            )
        }
    }
}
