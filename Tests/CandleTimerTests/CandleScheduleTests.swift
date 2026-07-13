import XCTest
@testable import CandleTimer

final class CandleScheduleTests: XCTestCase {
  func testReturnsMessagesAtExistingNotificationBoundaries() {
    let announcements = [
      Announcement(key: "60", secondsBeforeClose: 60, message: "60"),
      Announcement(key: "30", secondsBeforeClose: 30, message: "30"),
      Announcement(key: "10", secondsBeforeClose: 10, message: "10"),
      Announcement(key: "5", secondsBeforeClose: 5, message: "5"),
      Announcement(key: "confirmed", secondsBeforeClose: 1, message: "confirmed")
    ]
    let schedule = CandleSchedule(durationSeconds: 300, announcements: announcements)

    XCTAssertEqual(schedule.announcements(atUnixSecond: 240).map(\.key), ["60"])
    XCTAssertEqual(schedule.announcements(atUnixSecond: 270).map(\.key), ["30"])
    XCTAssertEqual(schedule.announcements(atUnixSecond: 290).map(\.key), ["10"])
    XCTAssertEqual(schedule.announcements(atUnixSecond: 295).map(\.key), ["5"])
    XCTAssertEqual(schedule.announcements(atUnixSecond: 299).map(\.key), ["confirmed"])
    XCTAssertTrue(schedule.announcements(atUnixSecond: 300).isEmpty)
  }

  func testIgnoresAnnouncementThatExceedsCandleDuration() {
    let schedule = CandleSchedule(
      durationSeconds: 30,
      announcements: [
        Announcement(key: "60", secondsBeforeClose: 60, message: "60")
      ]
    )

    XCTAssertTrue(schedule.announcements(atUnixSecond: 0).isEmpty)
  }
}
