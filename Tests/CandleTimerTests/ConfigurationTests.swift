import Foundation
import XCTest
@testable import CandleTimer

final class ConfigurationTests: XCTestCase {
  func testSampleConfigurationIsValid() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let configuration = try TimerConfiguration.load(
      from: repositoryRoot.appendingPathComponent("config.json.sample")
    )

    XCTAssertEqual(configuration.fallback?.intervalMinutes, 5)
    XCTAssertEqual(
      configuration.periods.first?.start.secondsSinceMidnight,
      8 * 60 * 60 + 45 * 60
    )
    XCTAssertEqual(configuration.periods.first?.candle.durationMinutes, 5)
    XCTAssertTrue(configuration.periods.dropFirst().allSatisfy { $0.candle.durationMinutes == 3 })
    XCTAssertEqual(configuration.periods.first?.rules.first?.when, .periodStarted)
    XCTAssertEqual(configuration.periods.first?.rules.last?.when, .candleClosed)
    XCTAssertEqual(configuration.periods.first?.rules.last?.speak.message, "５分経過")
    XCTAssertEqual(
      configuration.periods[1].end.secondsSinceMidnight,
      15 * 60 * 60 + 30 * 60
    )
    XCTAssertEqual(configuration.periods[1].candle.durationMinutes, 3)
    XCTAssertEqual(
      configuration.periods[1].rules.map(\.when),
      [
        .periodStarted,
        .secondsBeforeClose(60),
        .secondsBeforeClose(30),
        .secondsBeforeClose(10),
        .secondsBeforeClose(5),
        .candleClosed,
      ]
    )
  }

  func testParsesTimeZonePeriodsAndAllRuleConditions() throws {
    let configuration = try TimerConfiguration.parse(Self.validConfiguration)

    XCTAssertEqual(configuration.timeZone.identifier, "Asia/Tokyo")
    XCTAssertEqual(configuration.fallback?.intervalMinutes, 5)
    XCTAssertEqual(configuration.fallback?.speak.message, "市場がクローズしています")
    XCTAssertEqual(configuration.periods.count, 1)
    XCTAssertEqual(configuration.periods[0].start.secondsSinceMidnight, 9 * 60 * 60)
    XCTAssertEqual(configuration.periods[0].end.secondsSinceMidnight, 15 * 60 * 60 + 30 * 60)
    XCTAssertTrue(configuration.periods.allSatisfy { $0.candle.durationMinutes == 3 })
    XCTAssertEqual(
      configuration.periods[0].rules.map(\.when),
      [
        .periodStarted,
        .secondsBeforeClose(60),
        .secondsBeforeClose(30),
        .secondsBeforeClose(10),
        .secondsBeforeClose(5),
        .candleClosed,
      ]
    )
  }

  func testRejectsInvalidTimeZone() {
    let contents = Self.configuration(
      timeZone: "Invalid/TimeZone",
      periods: Self.period(start: "09:00", end: "09:30", durationMinutes: 1)
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(error as? ConfigurationError, .invalidTimeZone("Invalid/TimeZone"))
    }
  }

  func testRejectsNonIanaTimeZoneIdentifiers() {
    for identifier in ["GMT+0900", "PST"] {
      let contents = Self.configuration(
        timeZone: identifier,
        periods: Self.period(start: "09:00", end: "09:30", durationMinutes: 1)
      )

      XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
        XCTAssertEqual(error as? ConfigurationError, .invalidTimeZone(identifier))
      }
    }
  }

  func testRejectsNonPositiveFallbackInterval() {
    let contents =
      """
      {
        "timeZone": "Asia/Tokyo",
        "fallback": {
          "intervalMinutes": 0,
          "speak": { "message": "closed" }
        },
        "periods": [
          {
            "start": "09:00",
            "end": "09:30",
            "candle": { "durationMinutes": 1 },
            "rules": []
          }
        ]
      }
      """

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(error as? ConfigurationError, .invalidFallbackInterval)
    }
  }

  func testRejectsInvalidTimeFormat() {
    let contents = Self.configuration(
      periods: Self.period(start: "9:00", end: "09:30", durationMinutes: 1)
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(error as? ConfigurationError, .invalidTime("9:00"))
    }
  }

  func testRejectsEmptyPeriods() {
    XCTAssertThrowsError(
      try TimerConfiguration.parse(Self.configuration(periods: ""))
    ) { error in
      XCTAssertEqual(error as? ConfigurationError, .noPeriods)
    }
  }

  func testRejectsPeriodWhoseStartIsNotBeforeEnd() {
    let contents = Self.configuration(
      periods: Self.period(start: "09:30", end: "09:30", durationMinutes: 1)
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .invalidPeriodRange(periodNumber: 1)
      )
    }
  }

  func testRejectsPeriodsThatAreNotAscending() {
    let contents = Self.configuration(
      periods: [
        Self.period(start: "10:00", end: "10:30", durationMinutes: 1),
        Self.period(start: "09:00", end: "09:30", durationMinutes: 1)
      ].joined(separator: ",")
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .periodsNotAscending(periodNumber: 2)
      )
    }
  }

  func testRejectsOverlappingPeriods() {
    let contents = Self.configuration(
      periods: [
        Self.period(start: "09:00", end: "10:00", durationMinutes: 1),
        Self.period(start: "09:30", end: "10:30", durationMinutes: 1)
      ].joined(separator: ",")
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .overlappingPeriods(periodNumber: 2)
      )
    }
  }

  func testRejectsNonPositiveCandleDuration() {
    let contents = Self.configuration(
      periods: Self.period(start: "09:00", end: "09:30", durationMinutes: 0)
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .invalidDuration(periodNumber: 1)
      )
    }
  }

  func testRejectsPeriodNotDivisibleByCandleDuration() {
    let contents = Self.configuration(
      periods: Self.period(start: "09:00", end: "09:31", durationMinutes: 3)
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .periodDurationNotDivisible(periodNumber: 1)
      )
    }
  }

  func testRejectsRuleWithMultipleConditions() {
    let rules =
      """
      {
        "when": { "secondsBeforeClose": 10, "candleClosed": true },
        "speak": { "message": "invalid" }
      }
      """
    let contents = Self.configuration(
      periods: Self.period(
        start: "09:00",
        end: "09:30",
        durationMinutes: 1,
        rules: rules
      )
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .invalidSpeechCondition(path: "periods[0].rules[0].when")
      )
    }
  }

  func testRejectsRuleWithoutCondition() {
    let rules =
      """
      {
        "when": {},
        "speak": { "message": "invalid" }
      }
      """
    let contents = Self.configuration(
      periods: Self.period(
        start: "09:00",
        end: "09:30",
        durationMinutes: 1,
        rules: rules
      )
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .invalidSpeechCondition(path: "periods[0].rules[0].when")
      )
    }
  }

  func testRejectsUnknownRuleCondition() {
    let rules =
      """
      {
        "when": { "secondsBeforeClose": 10, "unknown": true },
        "speak": { "message": "invalid" }
      }
      """
    let contents = Self.configuration(
      periods: Self.period(
        start: "09:00",
        end: "09:30",
        durationMinutes: 1,
        rules: rules
      )
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .invalidSpeechCondition(path: "periods[0].rules[0].when")
      )
    }
  }

  func testRejectsFalseBooleanCondition() {
    let rules =
      """
      {
        "when": { "candleClosed": false },
        "speak": { "message": "invalid" }
      }
      """
    let contents = Self.configuration(
      periods: Self.period(
        start: "09:00",
        end: "09:30",
        durationMinutes: 1,
        rules: rules
      )
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .invalidSpeechCondition(path: "periods[0].rules[0].when")
      )
    }
  }

  func testReportsInvalidConditionPathForLaterPeriodAndRule() {
    let rules =
      """
      {
        "when": { "candleClosed": true },
        "speak": { "message": "valid" }
      },
      {
        "when": {},
        "speak": { "message": "invalid" }
      }
      """
    let contents = Self.configuration(
      periods: [
        Self.period(start: "09:00", end: "09:30", durationMinutes: 1),
        Self.period(
          start: "09:30",
          end: "10:00",
          durationMinutes: 1,
          rules: rules
        )
      ].joined(separator: ",")
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .invalidSpeechCondition(path: "periods[1].rules[1].when")
      )
    }
  }

  func testRejectsSecondsBeforeCloseOutsideCandleDuration() {
    let rules =
      """
      {
        "when": { "secondsBeforeClose": 61 },
        "speak": { "message": "too early" }
      }
      """
    let contents = Self.configuration(
      periods: Self.period(
        start: "09:00",
        end: "09:30",
        durationMinutes: 1,
        rules: rules
      )
    )

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .invalidSecondsBeforeClose(periodNumber: 1, ruleNumber: 1, maximum: 60)
      )
    }
  }

  func testRejectsLegacyConfigurationFormat() {
    let contents =
      """
      {
        "candle": { "durationMinutes": 5 },
        "rules": []
      }
      """

    XCTAssertThrowsError(try TimerConfiguration.parse(contents))
  }

  func testRejectsMalformedJSON() {
    XCTAssertThrowsError(try TimerConfiguration.parse("{ invalid json }")) { error in
      guard case .invalidJSON = error as? ConfigurationError else {
        return XCTFail("Expected invalidJSON, got \(error)")
      }
    }
  }

  func testReportsMissingFile() {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("candle-timer-missing-\(UUID().uuidString).json")

    XCTAssertThrowsError(try TimerConfiguration.load(from: url)) { error in
      XCTAssertEqual(error as? ConfigurationError, .fileNotFound(url))
    }
  }

  static let validConfiguration =
    """
    {
      "timeZone": "Asia/Tokyo",
      "fallback": {
        "intervalMinutes": 5,
        "speak": { "message": "市場がクローズしています" }
      },
      "periods": [
        {
          "start": "09:00",
          "end": "15:30",
          "candle": { "durationMinutes": 3 },
          "rules": [
            {
              "when": { "periodStarted": true },
              "speak": { "message": "9時です。3分足にきりかえてください。" }
            },
            {
              "when": { "secondsBeforeClose": 60 },
              "speak": { "message": "残り1分" }
            },
            {
              "when": { "secondsBeforeClose": 30 },
              "speak": { "message": "30秒前" }
            },
            {
              "when": { "secondsBeforeClose": 10 },
              "speak": { "message": "10秒前" }
            },
            {
              "when": { "secondsBeforeClose": 5 },
              "speak": { "message": "5秒前" }
            },
            {
              "when": { "candleClosed": true },
              "speak": { "message": "ローソク確定" }
            }
          ]
        }
      ]
    }
    """

  private static func configuration(
    timeZone: String = "Asia/Tokyo",
    periods: String
  ) -> String {
    """
    {
      "timeZone": "\(timeZone)",
      "periods": [\(periods)]
    }
    """
  }

  private static func period(
    start: String,
    end: String,
    durationMinutes: Int,
    rules: String = ""
  ) -> String {
    """
    {
      "start": "\(start)",
      "end": "\(end)",
      "candle": { "durationMinutes": \(durationMinutes) },
      "rules": [\(rules)]
    }
    """
  }
}
