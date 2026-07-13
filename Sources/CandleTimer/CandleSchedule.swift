struct Announcement: Equatable {
  let key: String
  let secondsBeforeClose: Int
  let message: String
}

struct CandleSchedule {
  let durationSeconds: Int
  let announcements: [Announcement]

  func announcements(atUnixSecond unixSecond: Int) -> [Announcement] {
    let secondInCandle = positiveRemainder(unixSecond, dividedBy: durationSeconds)

    return announcements.filter { announcement in
      let triggerSecond = durationSeconds - announcement.secondsBeforeClose
      return triggerSecond >= 0 && secondInCandle == triggerSecond
    }
  }

  private func positiveRemainder(_ value: Int, dividedBy divisor: Int) -> Int {
    let remainder = value % divisor
    return remainder >= 0 ? remainder : remainder + divisor
  }
}
