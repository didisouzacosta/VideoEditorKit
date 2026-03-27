import CoreGraphics
import XCTest

@testable import VideoEditorKit

final class TimelineMetricsTests: XCTestCase {

    // MARK: - Public Methods

    func testPlaybackPositionXClampsCurrentTimeInsideTrimmedRange() {
        let metrics = TimelineMetrics(
            duration: 100,
            playbackRange: 20...80,
            currentTime: 10,
            width: 200
        )

        XCTAssertEqual(metrics.playbackPositionX(), 44, accuracy: 0.0001)
    }

    func testPlaybackPositionXReturnsMinimumXForZeroDuration() {
        let metrics = TimelineMetrics(
            duration: 0,
            playbackRange: 0...0,
            currentTime: 0,
            width: 200
        )

        XCTAssertEqual(metrics.playbackPositionX(), 2, accuracy: 0.0001)
    }

    func testCurrentClipTimeSubtractsRangeLowerBound() {
        let metrics = TimelineMetrics(
            duration: 120,
            playbackRange: 30...90,
            currentTime: 45,
            width: 240
        )

        XCTAssertEqual(metrics.currentClipTime(), 15, accuracy: 0.0001)
    }

    func testPlaybackTimeClampsTouchBeforeRangeStart() {
        let metrics = TimelineMetrics(
            duration: 100,
            playbackRange: 20...80,
            currentTime: 50,
            width: 200
        )

        XCTAssertEqual(metrics.playbackTime(for: 10), 20, accuracy: 0.0001)
    }

    func testPlaybackTimeClampsTouchAfterRangeEnd() {
        let metrics = TimelineMetrics(
            duration: 100,
            playbackRange: 20...80,
            currentTime: 50,
            width: 200
        )

        XCTAssertEqual(metrics.playbackTime(for: 190), 80, accuracy: 0.0001)
    }

    func testBadgePositionXUsesMeasuredWidthNearLeadingEdge() {
        let metrics = TimelineMetrics(
            duration: 100,
            playbackRange: 0...100,
            currentTime: 0,
            width: 200
        )

        XCTAssertEqual(metrics.badgePositionX(for: 120), 60, accuracy: 0.0001)
    }

    func testBadgePositionXUsesMeasuredWidthNearTrailingEdge() {
        let metrics = TimelineMetrics(
            duration: 100,
            playbackRange: 0...100,
            currentTime: 100,
            width: 200
        )

        XCTAssertEqual(metrics.badgePositionX(for: 120), 140, accuracy: 0.0001)
    }

}
