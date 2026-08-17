import XCTest
@testable import CandleTimer

final class CandleTimerRunnerTests: XCTestCase {
  func testSpeaksAllBoundaryMessagesOneSecondEarlyOnceAndInOrder() throws {
    let synthesizer = RecordingSpeechSynthesizer()
    let runner = CandleTimerRunner(
      schedule: CandleSchedule(
        configuration: try TimerConfiguration.parse(ConfigurationTests.validConfiguration)
      ),
      synthesizer: synthesizer
    )
    let switchSecond = unixSecond("2026-07-13T00:30:00Z")

    runner.tick(atUnixSecond: switchSecond - 1)
    runner.tick(atUnixSecond: switchSecond - 1)
    runner.tick(atUnixSecond: switchSecond)

    XCTAssertEqual(
      synthesizer.messages,
      ["ローソク確定", "9時30分です。3分足に切り替えてください"]
    )
  }

  func testSpeaksFallbackImmediatelyWhenLaunchedOutsidePeriodsThenEveryInterval() throws {
    let synthesizer = RecordingSpeechSynthesizer()
    let runner = CandleTimerRunner(
      schedule: CandleSchedule(
        configuration: try TimerConfiguration.parse(ConfigurationTests.validConfiguration)
      ),
      synthesizer: synthesizer
    )
    let launchSecond = unixSecond("2026-07-13T07:00:00Z")

    runner.tick(atUnixSecond: launchSecond)
    runner.tick(atUnixSecond: launchSecond)
    runner.tick(atUnixSecond: launchSecond + 299)
    runner.tick(atUnixSecond: launchSecond + 300)

    XCTAssertEqual(
      synthesizer.messages,
      ["市場がクローズしています", "市場がクローズしています"]
    )
  }

  func testWaitsOneIntervalAfterFinalCandleCloseBeforeFallback() throws {
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

  func testResetsFallbackIntervalWhenEnteringAndLeavingPeriod() throws {
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

    XCTAssertEqual(
      synthesizer.messages,
      ["市場がクローズしています", "市場がクローズしています"]
    )
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
