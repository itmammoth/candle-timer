import Foundation
import XCTest
@testable import CandleTimer

final class ConfigurationTests: XCTestCase {
  func testParsesJSONRules() throws {
    let configuration = try TimerConfiguration.parse(
      """
      {
        "candle": {
          "durationMinutes": 5
        },
        "rules": [
          {
            "when": { "secondsBeforeClose": 45 },
            "speak": { "message": "45秒前" }
          },
          {
            "when": { "secondsBeforeClose": 1 },
            "speak": { "message": "ローソク足が確定しました" }
          }
        ]
      }
      """
    )

    XCTAssertEqual(configuration.candle.durationMinutes, 5)
    XCTAssertEqual(configuration.candleDurationSeconds, 300)
    XCTAssertEqual(configuration.messages.map(\.secondsBeforeClose), [45, 1])
    XCTAssertEqual(configuration.messages.last?.message, "ローソク足が確定しました")
  }

  func testOmitsRulesWithEmptyMessages() throws {
    let configuration = try TimerConfiguration.parse(
      """
      {
        "candle": { "durationMinutes": 3 },
        "rules": [
          {
            "when": { "secondsBeforeClose": 60 },
            "speak": { "message": "" }
          },
          {
            "when": { "secondsBeforeClose": 30 },
            "speak": { "message": "30秒前" }
          }
        ]
      }
      """
    )

    XCTAssertEqual(configuration.messages.count, 1)
    XCTAssertEqual(configuration.messages.first?.key, "rule-2")
  }

  func testRejectsNonPositiveDuration() {
    let contents =
      """
      {
        "candle": { "durationMinutes": 0 },
        "rules": []
      }
      """

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(error as? ConfigurationError, .invalidDuration)
    }
  }

  func testRejectsSecondsBeforeCloseOutsideCandleDuration() {
    let contents =
      """
      {
        "candle": { "durationMinutes": 1 },
        "rules": [
          {
            "when": { "secondsBeforeClose": 61 },
            "speak": { "message": "too early" }
          }
        ]
      }
      """

    XCTAssertThrowsError(try TimerConfiguration.parse(contents)) { error in
      XCTAssertEqual(
        error as? ConfigurationError,
        .invalidSecondsBeforeClose(ruleNumber: 1, maximum: 60)
      )
    }
  }

  func testRejectsMalformedJSON() {
    XCTAssertThrowsError(try TimerConfiguration.parse("{ invalid json }")) { error in
      guard case .invalidJSON = error as? ConfigurationError else {
        return XCTFail("Expected invalidJSON, got \(error)")
      }
    }
  }

  func testReportsMissingFile() {
    let url = URL(fileURLWithPath: "/tmp/candle-timer-missing.json")

    XCTAssertThrowsError(try TimerConfiguration.load(from: url)) { error in
      XCTAssertEqual(error as? ConfigurationError, .fileNotFound(url))
    }
  }
}
