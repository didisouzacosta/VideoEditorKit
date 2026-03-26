import UIKit
import XCTest

@testable import VideoEditorKit

@MainActor
final class VideoModelTests: XCTestCase {

    // MARK: - Public Methods

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

    func testThumbnailImagePreservesOriginalImageSize() {
        let sourceImage = UIGraphicsImageRenderer(
            size: CGSize(width: 400, height: 200)
        ).image { context in
            UIColor.red.setFill()
            context.fill(
                CGRect(
                    origin: .zero,
                    size: CGSize(width: 400, height: 200)
                )
            )
        }

        let thumbnailImage = ThumbnailImage(image: sourceImage)

        XCTAssertEqual(thumbnailImage.image?.size.width ?? 0, 400, accuracy: 0.0001)
        XCTAssertEqual(thumbnailImage.image?.size.height ?? 0, 200, accuracy: 0.0001)
    }

}
