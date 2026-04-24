import Foundation

public struct RecurrenceRuleFormatStyle: Sendable {
  public typealias RecurrenceRule = Calendar.RecurrenceRule

  public enum NameStyle: String, Sendable, Codable, Hashable {
    case long
    case abbreviated
    case short
    case narrow
  }

  public let calendar: Calendar
  public let locale: Locale
  public let timeZone: TimeZone
  public let weekdayStyle: NameStyle
  public let monthStyle: NameStyle

  public init(
    calendar: Calendar = .current,
    locale: Locale = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent,
    weekdayStyle: NameStyle = .long,
    monthStyle: NameStyle = .long
  ) {
    self.calendar = calendar
    self.locale = locale
    self.timeZone = timeZone
    self.weekdayStyle = weekdayStyle
    self.monthStyle = monthStyle
  }
}

extension Calendar.RecurrenceRule {
    
    public func formatted(
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        weekdayStyle: RecurrenceRuleFormatStyle.NameStyle = .long,
        monthStyle: RecurrenceRuleFormatStyle.NameStyle = .long
    ) -> String {
        formatted(RecurrenceRuleFormatStyle(
            calendar: calendar,
            locale: locale,
            timeZone: timeZone,
            weekdayStyle: .abbreviated,
            monthStyle: .abbreviated
        ))
    }
}

extension RecurrenceRuleFormatStyle: FormatStyle {
  public func format(_ rule: RecurrenceRule) -> String {
    var segments: [String] = [cadenceText(for: rule)]

    if let schedule = scheduleText(for: rule) {
      segments.append(schedule)
    }

    if let time = timeText(for: rule) {
      segments.append(time)
    }

    if let end = endText(for: rule.end) {
      segments.append(end)
    }

    if !rule.setPositions.isEmpty {
      segments.append("positions \(list(of: rule.setPositions.map(String.init)))")
    }

    return segments.joined(separator: " • ")
  }

  private func cadenceText(for rule: RecurrenceRule) -> String {
    let unit: String = switch rule.frequency {
    case .minutely: "minute"
    case .hourly: "hour"
    case .daily: "day"
    case .weekly: "week"
    case .monthly: "month"
    case .yearly: "year"
    @unknown default: "period"
    }

    if rule.interval == 1 {
      return "Every \(unit)"
    }
    return "Every \(rule.interval) \(unit)s"
  }

  private func scheduleText(for rule: RecurrenceRule) -> String? {
    var parts: [String] = []

    if !rule.weekdays.isEmpty {
      parts.append("on \(weekdayListText(rule.weekdays, rule: rule))")
    }

    if !rule.daysOfTheMonth.isEmpty {
      parts.append("on day \(list(of: rule.daysOfTheMonth.map(dayOfMonthText)))")
    }

    if !rule.months.isEmpty {
      parts.append("in \(list(of: rule.months.map(monthText)))")
    }

    if !rule.weeks.isEmpty {
      parts.append("in week \(list(of: rule.weeks.map(String.init)))")
    }

    if !rule.daysOfTheYear.isEmpty {
      parts.append("on day-of-year \(list(of: rule.daysOfTheYear.map(String.init)))")
    }

    guard !parts.isEmpty else { return nil }
    return parts.joined(separator: " ")
  }

  private func weekdayListText(_ weekdays: [RecurrenceRule.Weekday], rule: RecurrenceRule) -> String {
    var everyDays: [Locale.Weekday] = []
    everyDays.reserveCapacity(weekdays.count)

    for weekday in weekdays {
      switch weekday {
      case let .every(value):
        everyDays.append(value)
      case .nth:
        return list(of: weekdays.map(weekdayText))
      @unknown default:
        return list(of: weekdays.map(weekdayText))
      }
    }

    let ordered = orderedWeekdays(for: rule)
    let positionByDay = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($1, $0) })

    let uniqueSorted = Set(everyDays).compactMap { positionByDay[$0] }.sorted()
    guard !uniqueSorted.isEmpty else { return list(of: weekdays.map(weekdayText)) }

    var ranges: [(start: Int, end: Int)] = []
    var runStart = uniqueSorted[0]
    var previous = uniqueSorted[0]

    for value in uniqueSorted.dropFirst() {
      if value == previous + 1 {
        previous = value
        continue
      }
      ranges.append((runStart, previous))
      runStart = value
      previous = value
    }
    ranges.append((runStart, previous))

    // Treat week edges as adjacent for compaction (e.g. Sunday-Monday when week starts Monday).
    if ranges.count > 1, ranges.first?.start == 0, ranges.last?.end == 6 {
      let first = ranges.removeFirst()
      let last = ranges.removeLast()
      ranges.append((start: last.start, end: first.end))
    }

    let compacted = ranges.map { range -> String in
      let startDay = ordered[range.start]
      let endDay = ordered[range.end]
      if range.start == range.end {
        return weekdayName(startDay)
      }
      return "\(weekdayName(startDay))-\(weekdayName(endDay))"
    }

    return list(of: compacted)
  }

  private func timeText(for rule: RecurrenceRule) -> String? {
    guard !rule.hours.isEmpty else { return nil }

    let minutes = rule.minutes.isEmpty ? [0] : rule.minutes.sorted()
    let seconds = rule.seconds.isEmpty ? [0] : rule.seconds.sorted()

    guard minutes.count == 1, seconds.count == 1 else {
      return "at selected times"
    }

    let minute = minutes[0]
    let second = seconds[0]
    let hourValues = rule.hours.sorted()

    let dateFormatter = DateFormatter()
    dateFormatter.locale = locale
    dateFormatter.timeZone = timeZone
    dateFormatter.calendar = calendar
    dateFormatter.dateStyle = .none
    dateFormatter.timeStyle = .short

    let baseDate = Date(timeIntervalSince1970: 0)
    let values: [String] = hourValues.compactMap { hour -> String? in
      var components = DateComponents()
      components.calendar = calendar
      components.timeZone = timeZone
      components.year = 2026
      components.month = 1
      components.day = 1
      components.hour = hour
      components.minute = minute
      components.second = second
      guard let date = components.date else { return nil }
      return dateFormatter.string(from: date)
    }

    guard !values.isEmpty else {
      return "at \(dateFormatter.string(from: baseDate))"
    }
    return "at \(list(of: values))"
  }

  private func endText(for end: RecurrenceRule.End) -> String? {
    if #available(iOS 18.2, macCatalyst 18.2, macOS 15.2, tvOS 18.2, visionOS 2.2, watchOS 11.2, *) {
      if let count = end.occurrences {
//          return count == 1 ? "for 1 occurrence" : "for \(count) occurrences"
          return count == 1 ? "1 time" : "\(count) times"
      }
      if let date = end.date {
        return "until \(formattedDate(date))"
      }
    }
    return nil
  }

  private func formattedDate(_ date: Date) -> String {
    var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
    style.locale = locale
    style.calendar = calendar
    style.timeZone = timeZone
    return date.formatted(style)
  }

  private func weekdayText(_ weekday: RecurrenceRule.Weekday) -> String {
    switch weekday {
    case let .every(value):
      return weekdayName(value)
    case let .nth(ordinal, value):
      let name = weekdayName(value)
      if ordinal == -1 {
        return "last \(name)"
      }
      if ordinal < -1 {
        return "\(ordinalText(abs(ordinal))) last \(name)"
      }
      return "\(ordinalText(ordinal)) \(name)"
    @unknown default:
      return "weekday"
    }
  }

  private func weekdayName(_ weekday: Locale.Weekday) -> String {
    let symbols = weekdaySymbols()
    let index: Int = switch weekday {
    case .sunday: 0
    case .monday: 1
    case .tuesday: 2
    case .wednesday: 3
    case .thursday: 4
    case .friday: 5
    case .saturday: 6
    @unknown default: 0
    }

    if symbols.indices.contains(index) {
      return symbols[index]
    }
    return "day"
  }

  private func dayOfMonthText(_ day: Int) -> String {
    if day == -1 {
      return "last"
    }
    if day < -1 {
      return "\(ordinalText(abs(day))) last"
    }
    return ordinalText(day)
  }

  private func monthText(_ month: RecurrenceRule.Month) -> String {
    let index = month.index - 1
    let symbols = monthSymbols()
    if symbols.indices.contains(index) {
      return symbols[index]
    }
    return String(month.index)
  }

  private func weekdaySymbols() -> [String] {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = calendar
    formatter.timeZone = timeZone

    return switch weekdayStyle {
    case .long: formatter.weekdaySymbols
    case .abbreviated: formatter.shortWeekdaySymbols
    case .short: formatter.veryShortWeekdaySymbols
    case .narrow: formatter.veryShortWeekdaySymbols
    }
  }

  private func orderedWeekdays(for rule: RecurrenceRule) -> [Locale.Weekday] {
    let all: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    let index = max(0, min(6, rule.calendar.firstWeekday - 1))
    return Array(all[index...] + all[..<index])
  }

  private func monthSymbols() -> [String] {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = calendar
    formatter.timeZone = timeZone

    return switch monthStyle {
    case .long: formatter.monthSymbols
    case .abbreviated: formatter.shortMonthSymbols
    case .short: formatter.veryShortMonthSymbols
    case .narrow: formatter.veryShortMonthSymbols
    }
  }

  private func ordinalText(_ value: Int) -> String {
    guard value > 0 else { return String(value) }

    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .ordinal
    return formatter.string(from: NSNumber(value: value)) ?? String(value)
  }

  private func list(of values: [String]) -> String {
    let formatter = ListFormatter()
    formatter.locale = locale
    return formatter.string(from: values) ?? values.joined(separator: ", ")
  }
}

public extension FormatStyle where Self == RecurrenceRuleFormatStyle {
  static var recurrenceRule: Self {
    Self(
      calendar: .current,
      locale: .autoupdatingCurrent,
      timeZone: .autoupdatingCurrent,
      weekdayStyle: .long,
      monthStyle: .long
    )
  }
}

@available(*, deprecated, renamed: "RecurrenceRuleFormatStyle")
public typealias RecurrenceRuleHumanReadableFormatStyle = RecurrenceRuleFormatStyle

public extension FormatStyle where Self == RecurrenceRuleFormatStyle {
  @available(*, deprecated, renamed: "recurrenceRule")
  static var recurrenceRuleHumanReadable: Self { .recurrenceRule }
}
