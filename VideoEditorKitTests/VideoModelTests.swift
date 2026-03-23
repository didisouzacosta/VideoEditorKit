import XCTest

@testable import VideoEditorKit

final class VideoModelTests: XCTestCase {
    func testUpdateRateRescalesSelectedRange() {
        var video = Video.mock
        video.rangeDuration = 2...8
        video.rate = 1

        video.updateRate(2)

        XCTAssertEqual(video.rangeDuration.lowerBound, 1, accuracy: 0.0001)
        XCTAssertEqual(video.rangeDuration.upperBound, 4, accuracy: 0.0001)
        XCTAssertEqual(video.rate, 2)
    }

    func testRotateCyclesBackToZeroAfterFullTurn() {
        var video = Video.mock

        video.rotate()
        video.rotate()
        video.rotate()
        video.rotate()

        XCTAssertEqual(video.rotation, 0)
    }

    func testAppliedToolAddsOnlyOnce() {
        var video = Video.mock

        video.appliedTool(for: .text)
        video.appliedTool(for: .text)

        XCTAssertEqual(video.toolsApplied, [ToolEnum.text.rawValue])
    }

    func testRemoveToolClearsPreviouslyAppliedTool() {
        var video = Video.mock
        video.appliedTool(for: .filters)

        video.removeTool(for: .filters)

        XCTAssertFalse(video.isAppliedTool(for: .filters))
        XCTAssertTrue(video.toolsApplied.isEmpty)
    }
}
