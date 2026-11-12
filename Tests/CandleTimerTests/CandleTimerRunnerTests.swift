import XCTest
@testable import CandleTimer

final class CandleTimerRunnerTests: XCTestCase {
  func testSpeaksBoundaryMessageOneSecondEarlyOnce() throws {
    let synthesizer = RecordingSpeechSynthesizer()
    let runner = CandleTimerRunner(
      schedule: CandleSchedule(
        configuration: try TimerConfiguration.parse(ConfigurationTests.validConfiguration)
      ),
      synthesizer: synthesizer
    )
    let candleCloseSecond = unixSecond("2026-07-13T01:30:00Z")

    runner.tick(atUnixSecond: candleCloseSecond - 1)
    runner.tick(atUnixSecond: candleCloseSecond - 1)
    runner.tick(atUnixSecond: candleCloseSecond)

    XCTAssertEqual(
      synthesizer.messages,
      ["ローソク確定"]
    )
  }

  func testSpeaksFallbackImmediatelyThenAtQuarterHoursRegardlessOfLaunchTime() throws {
    let synthesizer = RecordingSpeechSynthesizer()
    let runner = CandleTimerRunner(
      schedule: CandleSchedule(
        configuration: try TimerConfiguration.parse(
          ConfigurationTests.validConfiguration.replacingOccurrences(
            of: "\"intervalMinutes\": 5", with: "\"intervalMinutes\": 15"
          )
        )
      ),
      synthesizer: synthesizer
    )
    let launchSecond = unixSecond("2026-07-12T22:04:00Z")

    runner.tick(atUnixSecond: launchSecond)
    runner.tick(atUnixSecond: launchSecond)
    XCTAssertEqual(synthesizer.messages.count, 1)

    for timestamp in [
      "2026-07-12T22:15:00Z", "2026-07-12T22:30:00Z",
      "2026-07-12T22:45:00Z", "2026-07-12T23:00:00Z"
    ] {
      let boundary = unixSecond(timestamp)
      let previousCount = synthesizer.messages.count
      runner.tick(atUnixSecond: boundary - 2)
      XCTAssertEqual(synthesizer.messages.count, previousCount)
      runner.tick(atUnixSecond: boundary - 1)
      runner.tick(atUnixSecond: boundary - 1)
      runner.tick(atUnixSecond: boundary)
      XCTAssertEqual(synthesizer.messages.count, previousCount + 1)

      runner.tick(atUnixSecond: boundary + 4 * 60)
      XCTAssertEqual(synthesizer.messages.count, previousCount + 1)
    }

    XCTAssertEqual(
      synthesizer.messages,
      Array(repeating: "市場がクローズしています", count: 5)
    )
  }

  func testPrioritizesFinalCandleCloseThenSpeaksAtNextClockTime() throws {
    let synthesizer = RecordingSpeechSynthesizer()
    let runner = CandleTimerRunner(
      schedule: CandleSchedule(
        configuration: try TimerConfiguration.parse(ConfigurationTests.validConfiguration)
      ),
      synthesizer: synthesizer
    )
    let closeSecond = unixSecond("2026-07-13T06:30:00Z")

    runner.tick(atUnixSecond: closeSecond - 2)
    runner.tick(atUnixSecond: closeSecond - 1)
    runner.tick(atUnixSecond: closeSecond + 298)
    runner.tick(atUnixSecond: closeSecond + 299)

    XCTAssertEqual(
      synthesizer.messages,
      ["ローソク確定", "市場がクローズしています"]
    )
  }

  func testSpeaksImmediatelyWhenLeavingSilentPeriodThenUsesClockTime() throws {
    let configuration =
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
            "end": "09:01",
            "candle": { "durationMinutes": 1 },
            "rules": []
          }
        ]
      }
      """
    let synthesizer = RecordingSpeechSynthesizer()
    let runner = CandleTimerRunner(
      schedule: CandleSchedule(configuration: try TimerConfiguration.parse(configuration)),
      synthesizer: synthesizer
    )

    runner.tick(atUnixSecond: unixSecond("2026-07-12T23:59:30Z"))
    runner.tick(atUnixSecond: unixSecond("2026-07-13T00:00:00Z"))
    runner.tick(atUnixSecond: unixSecond("2026-07-13T00:01:00Z"))
    XCTAssertEqual(synthesizer.messages.count, 2)
    runner.tick(atUnixSecond: unixSecond("2026-07-13T00:04:58Z"))
    XCTAssertEqual(synthesizer.messages.count, 2)
    runner.tick(atUnixSecond: unixSecond("2026-07-13T00:04:59Z"))
    runner.tick(atUnixSecond: unixSecond("2026-07-13T00:06:00Z"))

    XCTAssertEqual(
      synthesizer.messages,
      Array(repeating: "市場がクローズしています", count: 3)
    )
  }

  func testUnalignedPeriodEndWaitsUntilNextClockTimeInsteadOfFullInterval() throws {
    let configuration = try TimerConfiguration.parse(
      ConfigurationTests.validConfiguration
        .replacingOccurrences(of: "15:30", with: "15:31")
        .replacingOccurrences(of: "\"durationMinutes\": 3", with: "\"durationMinutes\": 1")
    )
    let synthesizer = RecordingSpeechSynthesizer()
    let runner = CandleTimerRunner(
      schedule: CandleSchedule(configuration: configuration),
      synthesizer: synthesizer
    )

    runner.tick(atUnixSecond: unixSecond("2026-07-13T06:30:59Z"))
    runner.tick(atUnixSecond: unixSecond("2026-07-13T06:31:00Z"))
    runner.tick(atUnixSecond: unixSecond("2026-07-13T06:34:58Z"))
    XCTAssertEqual(synthesizer.messages, ["ローソク確定"])
    runner.tick(atUnixSecond: unixSecond("2026-07-13T06:34:59Z"))
    runner.tick(atUnixSecond: unixSecond("2026-07-13T06:35:59Z"))
    XCTAssertEqual(synthesizer.messages, ["ローソク確定", "市場がクローズしています"])
  }

  func testDoesNotReplayMissedFallbackAfterSleep() throws {
    let synthesizer = RecordingSpeechSynthesizer()
    let runner = CandleTimerRunner(
      schedule: CandleSchedule(
        configuration: try TimerConfiguration.parse(ConfigurationTests.validConfiguration)
      ),
      synthesizer: synthesizer
    )

    runner.tick(atUnixSecond: unixSecond("2026-07-12T22:04:00Z"))
    runner.tick(atUnixSecond: unixSecond("2026-07-12T22:19:00Z"))
    XCTAssertEqual(synthesizer.messages, ["市場がクローズしています"])
    runner.tick(atUnixSecond: unixSecond("2026-07-12T22:19:59Z"))
    XCTAssertEqual(synthesizer.messages.count, 2)
  }
}

final class SaySpeechSynthesizerTests: XCTestCase {
  func testTreatsMessageBeginningWithHyphenAsSpeechText() {
    XCTAssertEqual(
      SaySpeechSynthesizer.commandArguments(for: "-f/tmp/message.txt"),
      ["--", "-f/tmp/message.txt"]
    )
  }
}

private final class RecordingSpeechSynthesizer: SpeechSynthesizing {
  private(set) var messages: [String] = []

  func speak(_ message: String) {
    messages.append(message)
  }
}
