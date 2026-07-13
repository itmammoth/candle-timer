import XCTest
@testable import CandleTimer

final class CandleTimerRunnerTests: XCTestCase {
  func testSpeaksAllBoundaryMessagesOnceAndInOrder() throws {
    let synthesizer = RecordingSpeechSynthesizer()
    let runner = CandleTimerRunner(
      schedule: CandleSchedule(
        configuration: try TimerConfiguration.parse(ConfigurationTests.validConfiguration)
      ),
      synthesizer: synthesizer
    )
    let switchSecond = unixSecond("2026-07-13T00:30:00Z")

    runner.tick(atUnixSecond: switchSecond)
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

    runner.tick(atUnixSecond: closeSecond - 1)
    runner.tick(atUnixSecond: closeSecond)
    runner.tick(atUnixSecond: closeSecond + 299)
    runner.tick(atUnixSecond: closeSecond + 300)

    XCTAssertEqual(
      synthesizer.messages,
      ["ローソク確定", "市場がクローズしています"]
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
