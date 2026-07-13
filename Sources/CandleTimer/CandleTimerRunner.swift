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
  private let schedule: CandleSchedule
  private let synthesizer: SpeechSynthesizing
  private var lastEvaluatedSecond: Int?

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

    for announcement in schedule.announcements(atUnixSecond: currentSecond) {
      synthesizer.speak(announcement.message)
    }

    lastEvaluatedSecond = currentSecond
  }

  @objc private func handleTimer() {
    tick(atUnixSecond: Int(Date().timeIntervalSince1970))
  }
}
