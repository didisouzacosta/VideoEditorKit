import XCTest

@testable import VideoEditorKit

final class TimeIntervalFormattingTests: XCTestCase {
    func testMinuteSecondsFormatsFinitePositiveValues() {
        let interval: TimeInterval = 65

        XCTAssertEqual(interval.minuteSeconds, "01:05")
    }

    func testMinuteSecondsReturnsUnknownForInvalidValues() {
        XCTAssertEqual(TimeInterval.zero.minuteSeconds, "unknown")
        XCTAssertEqual(TimeInterval.infinity.minuteSeconds, "unknown")
    }

    func testFormatterTimeStringUsesTenthsPrecision() {
        let interval: TimeInterval = 65.37

        XCTAssertEqual(interval.formatterTimeString(), "1:05.3")
    }

    func testSecondsToTimeClampsNegativeValues() {
        XCTAssertEqual((-3).secondsToTime(), "00:00")
    }
}
