import Foundation

struct TimerConfiguration: Equatable {
  let candleDurationMinutes: Int
  let messages: [Announcement]

  var candleDurationSeconds: Int {
    candleDurationMinutes * 60
  }

  static func load(from url: URL) throws -> TimerConfiguration {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw ConfigurationError.fileNotFound(url)
    }

    let contents = try String(contentsOf: url, encoding: .utf8)
    return try parse(contents)
  }

  static func parse(_ contents: String) throws -> TimerConfiguration {
    var values: [String: String] = [:]

    for (index, line) in contents.components(separatedBy: .newlines).enumerated() {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else {
        continue
      }

      guard let separator = trimmedLine.firstIndex(of: "=") else {
        throw ConfigurationError.invalidLine(index + 1)
      }

      let key = trimmedLine[..<separator].trimmingCharacters(in: .whitespaces)
      let rawValue = trimmedLine[trimmedLine.index(after: separator)...]
        .trimmingCharacters(in: .whitespaces)

      guard !key.isEmpty else {
        throw ConfigurationError.invalidLine(index + 1)
      }

      values[key] = try parseValue(rawValue, lineNumber: index + 1)
    }

    guard let rawDuration = values["CANDLE_DURATION_MIN"],
          let duration = Int(rawDuration),
          duration > 0 else {
      throw ConfigurationError.invalidDuration
    }

    let definitions = [
      (key: "MSG_60_SEC", secondsBeforeClose: 60),
      (key: "MSG_30_SEC", secondsBeforeClose: 30),
      (key: "MSG_10_SEC", secondsBeforeClose: 10),
      (key: "MSG_5_SEC", secondsBeforeClose: 5),
      (key: "MSG_CONFIRMED", secondsBeforeClose: 1)
    ]

    let messages = definitions.compactMap { definition -> Announcement? in
      guard let message = values[definition.key], !message.isEmpty else {
        return nil
      }

      return Announcement(
        key: definition.key,
        secondsBeforeClose: definition.secondsBeforeClose,
        message: message
      )
    }

    return TimerConfiguration(
      candleDurationMinutes: duration,
      messages: messages
    )
  }

  private static func parseValue(
    _ rawValue: String,
    lineNumber: Int
  ) throws -> String {
    guard let first = rawValue.first else {
      return ""
    }

    if first == "\"" || first == "'" {
      guard rawValue.count >= 2, rawValue.last == first else {
        throw ConfigurationError.invalidLine(lineNumber)
      }

      return String(rawValue.dropFirst().dropLast())
    }

    return rawValue
  }
}

enum ConfigurationError: LocalizedError, Equatable {
  case fileNotFound(URL)
  case invalidLine(Int)
  case invalidDuration

  var errorDescription: String? {
    switch self {
    case .fileNotFound(let url):
      "Configuration file '\(url.path)' not found."
    case .invalidLine(let lineNumber):
      "Invalid configuration at line \(lineNumber)."
    case .invalidDuration:
      "CANDLE_DURATION_MIN must be a positive integer."
    }
  }
}
