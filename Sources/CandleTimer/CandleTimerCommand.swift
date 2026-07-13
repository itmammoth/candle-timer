import Foundation

@main
struct CandleTimerCommand {
  static func main() {
    do {
      try run()
    } catch {
      let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
      exit(EXIT_FAILURE)
    }
  }

  private static func run() throws {
    let configurationURL = locateConfigurationFile()
    let configuration = try TimerConfiguration.load(from: configurationURL)
    let schedule = CandleSchedule(
      durationSeconds: configuration.candleDurationSeconds,
      announcements: configuration.messages
    )
    let runner = CandleTimerRunner(
      schedule: schedule,
      synthesizer: SaySpeechSynthesizer()
    )
    runner.run()
  }

  private static func locateConfigurationFile() -> URL {
    let fileManager = FileManager.default
    let executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      .standardizedFileURL
    let executableCandidate = executableURL
      .deletingLastPathComponent()
      .appendingPathComponent("config.json")
    let workingDirectoryCandidate = URL(fileURLWithPath: fileManager.currentDirectoryPath)
      .appendingPathComponent("config.json")

    if fileManager.fileExists(atPath: executableCandidate.path) {
      return executableCandidate
    }

    return workingDirectoryCandidate
  }
}
