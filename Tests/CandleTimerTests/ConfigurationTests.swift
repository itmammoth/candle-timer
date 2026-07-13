import Foundation
import XCTest
@testable import CandleTimer

final class ConfigurationTests: XCTestCase {
  func testParsesExistingConfigurationFormat() throws {
    let configuration = try TimerConfiguration.parse(
      """
      CANDLE_DURATION_MIN=5

      MSG_60_SEC="60 seconds remaining"
      MSG_30_SEC="30 seconds remaining"
      MSG_10_SEC="10 seconds remaining"
      MSG_5_SEC="5 seconds remaining"
      MSG_CONFIRMED="Candle closed"
      """
    )

    XCTAssertEqual(configuration.candleDurationMinutes, 5)
    XCTAssertEqual(configuration.candleDurationSeconds, 300)
    XCTAssertEqual(
      configuration.messages.map(\.secondsBeforeClose),
      [60, 30, 10, 5, 1]
    )
    XCTAssertEqual(configuration.messages.last?.message, "Candle closed")
  }

  func testOmitsEmptyOptionalMessages() throws {
    let configuration = try TimerConfiguration.parse(
      """
      CANDLE_DURATION_MIN=3
      MSG_60_SEC=""
      MSG_30_SEC="30秒前"
      """
    )

    XCTAssertEqual(configuration.messages.count, 1)
    XCTAssertEqual(configuration.messages.first?.key, "MSG_30_SEC")
  }

  func testRejectsNonPositiveDuration() {
    XCTAssertThrowsError(try TimerConfiguration.parse("CANDLE_DURATION_MIN=0")) { error in
      XCTAssertEqual(error as? ConfigurationError, .invalidDuration)
    }
  }

  func testReportsMissingFile() {
    let url = URL(fileURLWithPath: "/tmp/candle-timer-missing.conf")

    XCTAssertThrowsError(try TimerConfiguration.load(from: url)) { error in
      XCTAssertEqual(error as? ConfigurationError, .fileNotFound(url))
    }
  }
}
