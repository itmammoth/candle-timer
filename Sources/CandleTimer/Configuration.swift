import Foundation

struct TimerConfiguration: Decodable, Equatable {
  let candle: CandleConfiguration
  let rules: [SpeechRule]

  var candleDurationSeconds: Int {
    candle.durationMinutes * 60
  }

  var announcements: [Announcement] {
    rules.compactMap { rule in
      guard !rule.speak.message.isEmpty else {
        return nil
      }

      return Announcement(
        secondsBeforeClose: rule.when.secondsBeforeClose,
        message: rule.speak.message
      )
    }
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
    guard candle.durationMinutes > 0 else {
      throw ConfigurationError.invalidDuration
    }

    for (index, rule) in rules.enumerated() {
      let seconds = rule.when.secondsBeforeClose
      guard seconds > 0, seconds <= candleDurationSeconds else {
        throw ConfigurationError.invalidSecondsBeforeClose(
          ruleNumber: index + 1,
          maximum: candleDurationSeconds
        )
      }
    }
  }
}

struct CandleConfiguration: Decodable, Equatable {
  let durationMinutes: Int
}

struct SpeechRule: Decodable, Equatable {
  let when: SpeechCondition
  let speak: SpeechAction
}

struct SpeechCondition: Decodable, Equatable {
  let secondsBeforeClose: Int
}

struct SpeechAction: Decodable, Equatable {
  let message: String
}

enum ConfigurationError: LocalizedError, Equatable {
  case fileNotFound(URL)
  case invalidJSON(String)
  case invalidDuration
  case invalidSecondsBeforeClose(ruleNumber: Int, maximum: Int)

  var errorDescription: String? {
    switch self {
    case .fileNotFound(let url):
      "Configuration file '\(url.path)' not found."
    case .invalidJSON(let details):
      "Invalid JSON configuration: \(details)"
    case .invalidDuration:
      "candle.durationMinutes must be a positive integer."
    case .invalidSecondsBeforeClose(let ruleNumber, let maximum):
      "rules[\(ruleNumber - 1)].when.secondsBeforeClose must be between 1 and \(maximum)."
    }
  }
}
