import XCTest

@testable import VideoEditorKit

final class PlaybackTimeMappingTests: XCTestCase {

    // MARK: - Public Methods

    func testTimelineTimePreservingSourcePositionMapsToNewRate() {
        let mappedTime = PlaybackTimeMapping.timelineTimePreservingSourcePosition(
            timelineTime: 24,
            previousRate: 1,
            newRate: 2,
            newRange: 0...50,
            originalDuration: 100
        )

        XCTAssertEqual(mappedTime, 24, accuracy: 0.0001)
    }

    func testTimelineTimePreservingSourcePositionStaysFixedWhenSlowingDown() {
        let mappedTime = PlaybackTimeMapping.timelineTimePreservingSourcePosition(
            timelineTime: 12,
            previousRate: 2,
            newRate: 0.5,
            newRange: 0...200,
            originalDuration: 100
        )

        XCTAssertEqual(mappedTime, 12, accuracy: 0.0001)
    }

    func testTimelineTimePreservingSourcePositionClampsToUpdatedRange() {
        let mappedTime = PlaybackTimeMapping.timelineTimePreservingSourcePosition(
            timelineTime: 80,
            previousRate: 1,
            newRate: 2,
            newRange: 10...30,
            originalDuration: 100
        )

        XCTAssertEqual(mappedTime, 30, accuracy: 0.0001)
    }

    func testTimelineTimePreservingSourcePositionFallsBackToRateOneForInvalidRate() {
        let mappedTime = PlaybackTimeMapping.timelineTimePreservingSourcePosition(
            timelineTime: 20,
            previousRate: 0,
            newRate: 0,
            newRange: 0...100,
            originalDuration: 100
        )

        XCTAssertEqual(mappedTime, 20, accuracy: 0.0001)
    }

    func testScaledTimelineRangeDividesSourceRangeByRate() {
        let scaledRange = PlaybackTimeMapping.scaledTimelineRange(
            sourceRange: 20...80,
            rate: 2,
            originalDuration: 100
        )

        XCTAssertEqual(scaledRange.lowerBound, 10, accuracy: 0.0001)
        XCTAssertEqual(scaledRange.upperBound, 40, accuracy: 0.0001)
    }

}
