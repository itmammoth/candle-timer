import Foundation

struct Announcement: Equatable {
  let condition: SpeechCondition
  let message: String
}

struct FallbackAnnouncement: Equatable {
  let intervalSeconds: Int
  let message: String
}

struct ScheduleEvaluation: Equatable {
  let announcements: [Announcement]
  let fallback: FallbackAnnouncement?
}

struct CandleSchedule {
  private let timeZone: TimeZone
  private let fallback: FallbackAnnouncement?
  private let periods: [ScheduledPeriod]

  init(configuration: TimerConfiguration) {
    timeZone = configuration.timeZone
    fallback = configuration.fallback.flatMap { fallback in
      guard !fallback.speak.message.isEmpty else {
        return nil
      }

      return FallbackAnnouncement(
        intervalSeconds: fallback.intervalSeconds,
        message: fallback.speak.message
      )
    }
    periods = configuration.periods.map { period in
      ScheduledPeriod(
        startSecond: period.start.secondsSinceMidnight,
        endSecond: period.end.secondsSinceMidnight,
        durationSeconds: period.candleDurationSeconds,
        announcements: period.rules.compactMap { rule in
          guard !rule.speak.message.isEmpty else {
            return nil
          }

          return Announcement(condition: rule.when, message: rule.speak.message)
        }
      )
    }
  }

  func announcements(atUnixSecond unixSecond: Int) -> [Announcement] {
    evaluation(atUnixSecond: unixSecond).announcements
  }

  func evaluation(atUnixSecond unixSecond: Int) -> ScheduleEvaluation {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components = calendar.dateComponents(
      [.hour, .minute, .second],
      from: Date(timeIntervalSince1970: TimeInterval(unixSecond))
    )

    guard
      let hour = components.hour,
      let minute = components.minute,
      let second = components.second
    else {
      return ScheduleEvaluation(announcements: [], fallback: nil)
    }

    let secondOfDay = (hour * 60 + minute) * 60 + second
    let isWithinPeriod = periods.contains { period in
      period.contains(secondOfDay)
    }
    var matches: [AnnouncementMatch] = []

    for (periodIndex, period) in periods.enumerated() {
      for (ruleIndex, announcement) in period.announcements.enumerated() {
        guard period.matches(announcement.condition, at: secondOfDay) else {
          continue
        }

        matches.append(
          AnnouncementMatch(
            priority: announcement.condition.priority,
            periodIndex: periodIndex,
            ruleIndex: ruleIndex,
            announcement: announcement
          )
        )
      }
    }

    return ScheduleEvaluation(
      announcements: matches.sorted().map(\.announcement),
      fallback: isWithinPeriod ? nil : fallback
    )
  }
}

private struct ScheduledPeriod {
  let startSecond: Int
  let endSecond: Int
  let durationSeconds: Int
  let announcements: [Announcement]

  func contains(_ secondOfDay: Int) -> Bool {
    secondOfDay >= startSecond && secondOfDay < endSecond
  }

  func matches(_ condition: SpeechCondition, at secondOfDay: Int) -> Bool {
    switch condition {
    case .secondsBeforeClose(let seconds):
      guard secondOfDay >= startSecond, secondOfDay < endSecond else {
        return false
      }

      let secondInCandle = (secondOfDay - startSecond) % durationSeconds
      return secondInCandle == durationSeconds - seconds
    case .candleClosed:
      guard secondOfDay > startSecond, secondOfDay <= endSecond else {
        return false
      }

      return (secondOfDay - startSecond) % durationSeconds == 0
    case .periodStarted:
      return secondOfDay == startSecond
    }
  }
}

private extension SpeechCondition {
  var priority: Int {
    switch self {
    case .candleClosed:
      0
    case .periodStarted:
      1
    case .secondsBeforeClose:
      2
    }
  }
}

private struct AnnouncementMatch: Comparable {
  let priority: Int
  let periodIndex: Int
  let ruleIndex: Int
  let announcement: Announcement

  static func < (lhs: AnnouncementMatch, rhs: AnnouncementMatch) -> Bool {
    if lhs.priority != rhs.priority {
      return lhs.priority < rhs.priority
    }

    if lhs.periodIndex != rhs.periodIndex {
      return lhs.periodIndex < rhs.periodIndex
    }

    return lhs.ruleIndex < rhs.ruleIndex
  }
}
