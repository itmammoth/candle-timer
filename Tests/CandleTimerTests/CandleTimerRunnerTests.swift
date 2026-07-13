import XCTest
@testable import CandleTimer

final class CandleTimerRunnerTests: XCTestCase {
  func testSpeaksEachBoundaryOnlyOncePerSecond() {
    let synthesizer = RecordingSpeechSynthesizer()
    let runner = CandleTimerRunner(
      schedule: CandleSchedule(
        durationSeconds: 300,
        announcements: [
          Announcement(key: "60", secondsBeforeClose: 60, message: "60 seconds"),
          Announcement(key: "30", secondsBeforeClose: 30, message: "30 seconds")
        ]
      ),
      synthesizer: synthesizer
    )

    runner.tick(atUnixSecond: 240)
    runner.tick(atUnixSecond: 240)
    runner.tick(atUnixSecond: 270)

    XCTAssertEqual(synthesizer.messages, ["60 seconds", "30 seconds"])
  }
}

private final class RecordingSpeechSynthesizer: SpeechSynthesizing {
  private(set) var messages: [String] = []

  func speak(_ message: String) {
    messages.append(message)
  }
}
