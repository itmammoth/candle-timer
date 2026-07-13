import XCTest
@testable import CandleTimer

final class CandleScheduleTests: XCTestCase {
  func testReturnsMessagesAtExistingNotificationBoundaries() {
    let announcements = [
      Announcement(secondsBeforeClose: 60, message: "60"),
      Announcement(secondsBeforeClose: 30, message: "30"),
      Announcement(secondsBeforeClose: 10, message: "10"),
      Announcement(secondsBeforeClose: 5, message: "5"),
      Announcement(secondsBeforeClose: 1, message: "confirmed")
    ]
    let schedule = CandleSchedule(durationSeconds: 300, announcements: announcements)

    XCTAssertEqual(schedule.announcements(atUnixSecond: 240).map(\.message), ["60"])
    XCTAssertEqual(schedule.announcements(atUnixSecond: 270).map(\.message), ["30"])
    XCTAssertEqual(schedule.announcements(atUnixSecond: 290).map(\.message), ["10"])
    XCTAssertEqual(schedule.announcements(atUnixSecond: 295).map(\.message), ["5"])
    XCTAssertEqual(schedule.announcements(atUnixSecond: 299).map(\.message), ["confirmed"])
    XCTAssertTrue(schedule.announcements(atUnixSecond: 300).isEmpty)
  }

  func testIgnoresAnnouncementThatExceedsCandleDuration() {
    let schedule = CandleSchedule(
      durationSeconds: 30,
      announcements: [
        Announcement(secondsBeforeClose: 60, message: "60")
      ]
    )

    XCTAssertTrue(schedule.announcements(atUnixSecond: 0).isEmpty)
  }
}
