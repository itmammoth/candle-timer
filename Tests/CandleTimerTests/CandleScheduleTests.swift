import Foundation
import XCTest
@testable import CandleTimer

final class CandleScheduleTests: XCTestCase {
  private let schedule = CandleSchedule(
    configuration: try! TimerConfiguration.parse(ConfigurationTests.validConfiguration)
  )

  func testUsesThreeMinuteRulesFromNineOClock() {
    XCTAssertEqual(messages(at: "2026-07-13T00:02:00Z"), ["残り1分"])
    XCTAssertEqual(messages(at: "2026-07-13T00:02:30Z"), ["30秒前"])
    XCTAssertEqual(messages(at: "2026-07-13T00:02:50Z"), ["10秒前"])
    XCTAssertEqual(messages(at: "2026-07-13T00:02:55Z"), ["5秒前"])
    XCTAssertEqual(messages(at: "2026-07-13T00:03:00Z"), ["ローソク確定"])
    XCTAssertTrue(messages(at: "2026-07-13T00:06:00Z").contains("ローソク確定"))
  }

  func testTreatsTenThirtyAsRegularCandleClose() {
    XCTAssertEqual(
      messages(at: "2026-07-13T01:30:00Z"),
      ["ローソク確定"]
    )
  }

  func testContinuesThreeMinuteRulesAfterTenThirty() {
    XCTAssertEqual(messages(at: "2026-07-13T01:32:00Z"), ["残り1分"])
    XCTAssertEqual(messages(at: "2026-07-13T01:32:30Z"), ["30秒前"])
    XCTAssertEqual(messages(at: "2026-07-13T01:32:50Z"), ["10秒前"])
    XCTAssertEqual(messages(at: "2026-07-13T01:32:55Z"), ["5秒前"])
    XCTAssertEqual(messages(at: "2026-07-13T01:33:00Z"), ["ローソク確定"])
    XCTAssertEqual(messages(at: "2026-07-13T01:36:00Z"), ["ローソク確定"])
  }

  func testSpeaksFinalCandleCloseAtPeriodEnd() {
    XCTAssertEqual(messages(at: "2026-07-13T06:30:00Z"), ["ローソク確定"])
    XCTAssertTrue(messages(at: "2026-07-13T06:30:01Z").isEmpty)
  }

  func testDoesNotSpeakOutsideConfiguredPeriods() {
    XCTAssertTrue(messages(at: "2026-07-12T23:59:59Z").isEmpty)
    XCTAssertTrue(messages(at: "2026-07-13T07:00:00Z").isEmpty)
  }

  func testReturnsFallbackOnlyOutsideConfiguredPeriods() {
    let beforeOpen = schedule.evaluation(
      atUnixSecond: unixSecond("2026-07-12T23:59:59Z")
    )
    let duringMarket = schedule.evaluation(
      atUnixSecond: unixSecond("2026-07-13T00:00:00Z")
    )
    let atClose = schedule.evaluation(
      atUnixSecond: unixSecond("2026-07-13T06:30:00Z")
    )

    XCTAssertEqual(beforeOpen.fallback?.message, "市場がクローズしています")
    XCTAssertNil(duringMarket.fallback)
    XCTAssertEqual(atClose.announcements.map(\.message), ["ローソク確定"])
    XCTAssertEqual(atClose.fallback?.intervalSeconds, 300)
  }

  func testAllowsSilentGapBetweenPeriods() throws {
    let configuration = try TimerConfiguration.parse(
      """
      {
        "timeZone": "Asia/Tokyo",
        "periods": [
          {
            "start": "09:00",
            "end": "09:30",
            "candle": { "durationMinutes": 1 },
            "rules": [
              {
                "when": { "candleClosed": true },
                "speak": { "message": "first close" }
              }
            ]
          },
          {
            "start": "10:00",
            "end": "10:30",
            "candle": { "durationMinutes": 1 },
            "rules": []
          }
        ]
      }
      """
    )
    let gapSchedule = CandleSchedule(configuration: configuration)

    XCTAssertEqual(
      gapSchedule.announcements(atUnixSecond: unixSecond("2026-07-13T00:30:00Z")).map(\.message),
      ["first close"]
    )
    XCTAssertTrue(
      gapSchedule.announcements(atUnixSecond: unixSecond("2026-07-13T00:45:00Z")).isEmpty
    )
  }

  func testSkipsEmptyMessages() throws {
    let configuration = try TimerConfiguration.parse(
      """
      {
        "timeZone": "Asia/Tokyo",
        "periods": [
          {
            "start": "09:00",
            "end": "09:30",
            "candle": { "durationMinutes": 1 },
            "rules": [
              {
                "when": { "secondsBeforeClose": 10 },
                "speak": { "message": "" }
              }
            ]
          }
        ]
      }
      """
    )
    let emptyMessageSchedule = CandleSchedule(configuration: configuration)

    XCTAssertTrue(
      emptyMessageSchedule
        .announcements(atUnixSecond: unixSecond("2026-07-13T00:00:50Z"))
        .isEmpty
    )
  }

  func testAppliesScheduleEveryDay() {
    XCTAssertEqual(
      messages(at: "2026-07-14T01:30:00Z"),
      ["ローソク確定"]
    )
  }

  private func messages(at timestamp: String) -> [String] {
    schedule.announcements(atUnixSecond: unixSecond(timestamp)).map(\.message)
  }
}

func unixSecond(_ timestamp: String) -> Int {
  let formatter = ISO8601DateFormatter()
  return Int(formatter.date(from: timestamp)!.timeIntervalSince1970)
}
