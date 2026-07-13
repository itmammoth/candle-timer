import Foundation

struct TimerConfiguration: Decodable, Equatable {
  let timeZone: TimeZone
  let fallback: FallbackConfiguration?
  let periods: [PeriodConfiguration]

  private static let ianaTimeZoneIdentifiers = Set(TimeZone.knownTimeZoneIdentifiers)

  private enum CodingKeys: String, CodingKey {
    case timeZone
    case fallback
    case periods
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let timeZoneIdentifier = try container.decode(String.self, forKey: .timeZone)

    guard
      Self.ianaTimeZoneIdentifiers.contains(timeZoneIdentifier),
      let timeZone = TimeZone(identifier: timeZoneIdentifier)
    else {
      throw ConfigurationError.invalidTimeZone(timeZoneIdentifier)
    }

    self.timeZone = timeZone
    fallback = try container.decodeIfPresent(FallbackConfiguration.self, forKey: .fallback)
    periods = try container.decode([PeriodConfiguration].self, forKey: .periods)
  }

  static func load(from url: URL) throws -> TimerConfiguration {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw ConfigurationError.fileNotFound(url)
    }

    let contents = try String(contentsOf: url, encoding: .utf8)
    return try parse(contents)
  }

  static func parse(_ contents: String) throws -> TimerConfiguration {
    do {
      let configuration = try JSONDecoder().decode(
        TimerConfiguration.self,
        from: Data(contents.utf8)
      )
      try configuration.validate()
      return configuration
    } catch let error as ConfigurationError {
      throw error
    } catch {
      throw ConfigurationError.invalidJSON(error.localizedDescription)
    }
  }

  private func validate() throws {
    if let fallback {
      guard
        fallback.intervalMinutes > 0,
        fallback.intervalMinutes <= Int.max / 60
      else {
        throw ConfigurationError.invalidFallbackInterval
      }
    }

    guard !periods.isEmpty else {
      throw ConfigurationError.noPeriods
    }

    for (periodIndex, period) in periods.enumerated() {
      let periodNumber = periodIndex + 1

      guard period.start < period.end else {
        throw ConfigurationError.invalidPeriodRange(periodNumber: periodNumber)
      }

      guard
        period.candle.durationMinutes > 0,
        period.candle.durationMinutes <= Int.max / 60
      else {
        throw ConfigurationError.invalidDuration(periodNumber: periodNumber)
      }

      guard period.durationSeconds % period.candleDurationSeconds == 0 else {
        throw ConfigurationError.periodDurationNotDivisible(periodNumber: periodNumber)
      }

      for (ruleIndex, rule) in period.rules.enumerated() {
        guard case .secondsBeforeClose(let seconds) = rule.when else {
          continue
        }

        guard seconds > 0, seconds <= period.candleDurationSeconds else {
          throw ConfigurationError.invalidSecondsBeforeClose(
            periodNumber: periodNumber,
            ruleNumber: ruleIndex + 1,
            maximum: period.candleDurationSeconds
          )
        }
      }

      guard periodIndex > 0 else {
        continue
      }

      let previousPeriod = periods[periodIndex - 1]
      guard previousPeriod.start < period.start else {
        throw ConfigurationError.periodsNotAscending(periodNumber: periodNumber)
      }

      guard previousPeriod.end <= period.start else {
        throw ConfigurationError.overlappingPeriods(periodNumber: periodNumber)
      }
    }
  }
}

struct FallbackConfiguration: Decodable, Equatable {
  let intervalMinutes: Int
  let speak: SpeechAction

  var intervalSeconds: Int {
    intervalMinutes * 60
  }
}

struct PeriodConfiguration: Decodable, Equatable {
  let start: LocalTime
  let end: LocalTime
  let candle: CandleConfiguration
  let rules: [SpeechRule]

  var durationSeconds: Int {
    end.secondsSinceMidnight - start.secondsSinceMidnight
  }

  var candleDurationSeconds: Int {
    candle.durationMinutes * 60
  }
}

struct LocalTime: Decodable, Equatable, Comparable {
  let hour: Int
  let minute: Int

  var secondsSinceMidnight: Int {
    (hour * 60 + minute) * 60
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    let characters = Array(value)

    guard
      characters.count == 5,
      characters[2] == ":",
      characters[0].isNumber,
      characters[1].isNumber,
      characters[3].isNumber,
      characters[4].isNumber,
      let hour = Int(String(characters[0...1])),
      let minute = Int(String(characters[3...4])),
      (0...23).contains(hour),
      (0...59).contains(minute)
    else {
      throw ConfigurationError.invalidTime(value)
    }

    self.hour = hour
    self.minute = minute
  }

  static func < (lhs: LocalTime, rhs: LocalTime) -> Bool {
    lhs.secondsSinceMidnight < rhs.secondsSinceMidnight
  }
}

struct CandleConfiguration: Decodable, Equatable {
  let durationMinutes: Int
}

struct SpeechRule: Decodable, Equatable {
  let when: SpeechCondition
  let speak: SpeechAction
}

enum SpeechCondition: Decodable, Equatable {
  case secondsBeforeClose(Int)
  case candleClosed
  case periodStarted

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case secondsBeforeClose
    case candleClosed
    case periodStarted
  }

  init(from decoder: Decoder) throws {
    let conditionPath = Self.pathDescription(for: decoder.codingPath)
    let rawContainer = try decoder.container(keyedBy: ConditionKey.self)
    let validKeys = Set(CodingKeys.allCases.map(\.rawValue))
    guard
      rawContainer.allKeys.count == 1,
      rawContainer.allKeys.allSatisfy({ validKeys.contains($0.stringValue) })
    else {
      throw ConfigurationError.invalidSpeechCondition(path: conditionPath)
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    let secondsBeforeClose = try container.decodeIfPresent(Int.self, forKey: .secondsBeforeClose)
    let candleClosed = try container.decodeIfPresent(Bool.self, forKey: .candleClosed)
    let periodStarted = try container.decodeIfPresent(Bool.self, forKey: .periodStarted)
    let specifiedConditionCount = [
      secondsBeforeClose != nil,
      candleClosed != nil,
      periodStarted != nil
    ].filter { $0 }.count

    guard specifiedConditionCount == 1 else {
      throw ConfigurationError.invalidSpeechCondition(path: conditionPath)
    }

    if let secondsBeforeClose {
      self = .secondsBeforeClose(secondsBeforeClose)
    } else if candleClosed == true {
      self = .candleClosed
    } else if periodStarted == true {
      self = .periodStarted
    } else {
      throw ConfigurationError.invalidSpeechCondition(path: conditionPath)
    }
  }

  private static func pathDescription(for codingPath: [any CodingKey]) -> String {
    var result = ""

    for key in codingPath {
      if let index = key.intValue {
        result += "[\(index)]"
      } else {
        if !result.isEmpty {
          result += "."
        }
        result += key.stringValue
      }
    }

    return result.isEmpty ? "rule.when" : result
  }
}

private struct ConditionKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init?(intValue: Int) {
    stringValue = String(intValue)
    self.intValue = intValue
  }
}

struct SpeechAction: Decodable, Equatable {
  let message: String
}

enum ConfigurationError: LocalizedError, Equatable {
  case fileNotFound(URL)
  case invalidJSON(String)
  case invalidTimeZone(String)
  case invalidFallbackInterval
  case noPeriods
  case invalidTime(String)
  case invalidPeriodRange(periodNumber: Int)
  case periodsNotAscending(periodNumber: Int)
  case overlappingPeriods(periodNumber: Int)
  case invalidDuration(periodNumber: Int)
  case periodDurationNotDivisible(periodNumber: Int)
  case invalidSpeechCondition(path: String)
  case invalidSecondsBeforeClose(periodNumber: Int, ruleNumber: Int, maximum: Int)

  var errorDescription: String? {
    switch self {
    case .fileNotFound(let url):
      "Configuration file '\(url.path)' not found."
    case .invalidJSON(let details):
      "Invalid JSON configuration: \(details)"
    case .invalidTimeZone(let identifier):
      "timeZone '\(identifier)' is not a valid time zone identifier."
    case .invalidFallbackInterval:
      "fallback.intervalMinutes must be a positive integer."
    case .noPeriods:
      "periods must contain at least one period."
    case .invalidTime(let value):
      "Time '\(value)' must use HH:mm format and represent a valid time."
    case .invalidPeriodRange(let periodNumber):
      "periods[\(periodNumber - 1)].start must be earlier than its end."
    case .periodsNotAscending(let periodNumber):
      "periods[\(periodNumber - 1)] must start after the preceding period starts."
    case .overlappingPeriods(let periodNumber):
      "periods[\(periodNumber - 1)] must not overlap the preceding period."
    case .invalidDuration(let periodNumber):
      "periods[\(periodNumber - 1)].candle.durationMinutes must be a positive integer."
    case .periodDurationNotDivisible(let periodNumber):
      "periods[\(periodNumber - 1)] duration must be divisible by its candle duration."
    case .invalidSpeechCondition(let path):
      "\(path) must specify exactly one valid condition."
    case .invalidSecondsBeforeClose(let periodNumber, let ruleNumber, let maximum):
      "periods[\(periodNumber - 1)].rules[\(ruleNumber - 1)].when.secondsBeforeClose "
        + "must be between 1 and \(maximum)."
    }
  }
}
