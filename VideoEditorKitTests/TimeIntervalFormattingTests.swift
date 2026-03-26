import XCTest

@testable import VideoEditorKit

final class TimeIntervalFormattingTests: XCTestCase {

    // MARK: - Public Methods

    func testMinuteSecondsFormatsFinitePositiveValues() {
        let interval: TimeInterval = 65

        XCTAssertEqual(interval.minuteSeconds, "01:05")
    }

    func testMinuteSecondsReturnsUnknownForInvalidValues() {
        XCTAssertEqual(TimeInterval.zero.minuteSeconds, "unknown")
        XCTAssertEqual(TimeInterval.infinity.minuteSeconds, "unknown")
    }

    func testFormatterTimeStringFormatsHoursMinutesAndSecondsWhenNeeded() {
        let interval: TimeInterval = 5_422

        XCTAssertEqual(interval.formatterTimeString(), "01:30:22")
    }

    func testFormatterTimeStringFormatsLargeMinuteValuesWithoutHours() {
        let interval: TimeInterval = 1_992

        XCTAssertEqual(interval.formatterTimeString(), "33:12")
    }

    func testFormatterTimeStringFormatsTwoDigitMinutesAndSeconds() {
        let interval: TimeInterval = 71

        XCTAssertEqual(interval.formatterTimeString(), "01:11")
    }

    func testSecondsToTimeClampsNegativeValues() {
        XCTAssertEqual((-3).secondsToTime(), "00:00")
    }

}
