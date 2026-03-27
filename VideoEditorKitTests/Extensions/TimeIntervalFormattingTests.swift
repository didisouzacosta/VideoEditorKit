import Foundation
import Testing

@testable import VideoEditorKit

@Suite("TimeIntervalFormattingTests")
struct TimeIntervalFormattingTests {

    // MARK: - Public Methods

    @Test
    func minuteSecondsFormatsFinitePositiveValues() {
        let interval: TimeInterval = 65

        #expect(interval.minuteSeconds == "01:05")
    }

    @Test
    func minuteSecondsReturnsUnknownForInvalidValues() {
        #expect(TimeInterval.zero.minuteSeconds == "unknown")
        #expect(TimeInterval.infinity.minuteSeconds == "unknown")
    }

    @Test
    func formatterTimeStringFormatsHoursMinutesAndSecondsWhenNeeded() {
        let interval: TimeInterval = 5_422

        #expect(interval.formatterTimeString() == "01:30:22")
    }

    @Test
    func formatterTimeStringFormatsLargeMinuteValuesWithoutHours() {
        let interval: TimeInterval = 1_992

        #expect(interval.formatterTimeString() == "33:12")
    }

    @Test
    func formatterTimeStringFormatsTwoDigitMinutesAndSeconds() {
        let interval: TimeInterval = 71

        #expect(interval.formatterTimeString() == "01:11")
    }

    @Test
    func secondsToTimeClampsNegativeValues() {
        #expect((-3).secondsToTime() == "00:00")
    }

}
