import Foundation

protocol SpeechSynthesizing: AnyObject {
  func speak(_ message: String)
}

final class SaySpeechSynthesizer: SpeechSynthesizing {
  private let queue = DispatchQueue(label: "candle-timer.speech")

  func speak(_ message: String) {
    queue.async {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
      process.arguments = Self.commandArguments(for: message)

      do {
        try process.run()
        process.waitUntilExit()
      } catch {
        let output = "Error: Failed to start speech: \(error.localizedDescription)\n"
        FileHandle.standardError.write(Data(output.utf8))
      }
    }
  }

  static func commandArguments(for message: String) -> [String] {
    ["--", message]
  }
}

final class CandleTimerRunner: NSObject {
  private static let speechLeadSeconds = 1

  private let schedule: CandleSchedule
  private let synthesizer: SpeechSynthesizing
  private var lastEvaluatedSecond: Int?
  private var fallbackAnchorSecond: Int?

  init(schedule: CandleSchedule, synthesizer: SpeechSynthesizing) {
    self.schedule = schedule
    self.synthesizer = synthesizer
  }

  func run() {
    let timer = Timer(
      timeInterval: 0.1,
      target: self,
      selector: #selector(handleTimer),
      userInfo: nil,
      repeats: true
    )
    RunLoop.main.add(timer, forMode: .common)
    timer.fire()
    RunLoop.main.run()
  }

  func tick(atUnixSecond currentSecond: Int) {
    guard currentSecond != lastEvaluatedSecond else {
      return
    }

    let evaluation = schedule.evaluation(
      atUnixSecond: currentSecond + Self.speechLeadSeconds
    )

    for announcement in evaluation.announcements {
      synthesizer.speak(announcement.message)
    }

    handleFallback(
      evaluation.fallback,
      regularAnnouncementCount: evaluation.announcements.count,
      atUnixSecond: currentSecond
    )

    lastEvaluatedSecond = currentSecond
  }

  private func handleFallback(
    _ fallback: FallbackAnnouncement?,
    regularAnnouncementCount: Int,
    atUnixSecond currentSecond: Int
  ) {
    guard let fallback else {
      fallbackAnchorSecond = nil
      return
    }

    guard let anchorSecond = fallbackAnchorSecond else {
      fallbackAnchorSecond = currentSecond

      if regularAnnouncementCount == 0 {
        synthesizer.speak(fallback.message)
      }
      return
    }

    guard currentSecond - anchorSecond >= fallback.intervalSeconds else {
      return
    }

    synthesizer.speak(fallback.message)
    fallbackAnchorSecond = currentSecond
  }

  @objc private func handleTimer() {
    tick(atUnixSecond: Int(Date().timeIntervalSince1970))
  }
}
