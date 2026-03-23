import CoreGraphics
import Testing
@testable import VideoEditorKit

@MainActor
struct LayoutEngineTests {

    @Test func fitKeepsEntireLandscapeVideoVisibleInsideVerticalCanvas() {
        let videoSize = CGSize(width: 1920, height: 1080)
        let containerSize = CGSize(width: 270, height: 480)

        let result = LayoutEngine.computeLayout(
            videoSize: videoSize,
            containerSize: containerSize,
            preset: .instagram,
            gravity: .fit
        )

        #expect(result.renderSize == CGSize(width: 1080, height: 1920))
        assertRect(
            result.videoFrame,
            approximatelyEquals: CGRect(x: 0, y: 164.0625, width: 270, height: 151.875)
        )
        assertRect(
            transformedVideoBounds(videoSize: videoSize, transform: result.transform),
            approximatelyEquals: CGRect(x: 0, y: 656.25, width: 1080, height: 607.5)
        )
    }

    @Test func fillCropsLandscapeVideoHorizontallyInsideVerticalCanvas() {
        let videoSize = CGSize(width: 1920, height: 1080)
        let containerSize = CGSize(width: 270, height: 480)

        let result = LayoutEngine.computeLayout(
            videoSize: videoSize,
            containerSize: containerSize,
            preset: .instagram,
            gravity: .fill
        )

        assertRect(
            result.videoFrame,
            approximatelyEquals: CGRect(x: -291.6666666667, y: 0, width: 853.3333333333, height: 480)
        )
        assertRect(
            transformedVideoBounds(videoSize: videoSize, transform: result.transform),
            approximatelyEquals: CGRect(x: -1166.6666666667, y: 0, width: 3413.3333333333, height: 1920)
        )
    }

    @Test func originalPresetUsesSourceCanvasWhenNoRotationMetadataExists() {
        let videoSize = CGSize(width: 1920, height: 1080)
        let containerSize = CGSize(width: 320, height: 180)

        let result = LayoutEngine.computeLayout(
            videoSize: videoSize,
            containerSize: containerSize,
            preset: .original,
            gravity: .fit
        )

        #expect(result.renderSize == videoSize)
        assertRect(
            result.videoFrame,
            approximatelyEquals: CGRect(x: 0, y: 0, width: 320, height: 180)
        )
        assertRect(
            transformedVideoBounds(videoSize: videoSize, transform: result.transform),
            approximatelyEquals: CGRect(origin: .zero, size: videoSize)
        )
    }

    @Test func preferredTransformRotatesLandscapeNaturalSizeIntoPortraitLayout() {
        let videoSize = CGSize(width: 1920, height: 1080)
        let containerSize = CGSize(width: 270, height: 480)
        let portraitTransform = CGAffineTransform(
            a: 0,
            b: 1,
            c: -1,
            d: 0,
            tx: 1080,
            ty: 0
        )

        let result = LayoutEngine.computeLayout(
            videoSize: videoSize,
            containerSize: containerSize,
            preset: .original,
            gravity: .fit,
            preferredTransform: portraitTransform
        )

        #expect(result.renderSize == CGSize(width: 1080, height: 1920))
        assertRect(
            result.videoFrame,
            approximatelyEquals: CGRect(x: 0, y: 0, width: 270, height: 480)
        )
        assertRect(
            transformedVideoBounds(videoSize: videoSize, transform: result.transform),
            approximatelyEquals: CGRect(x: 0, y: 0, width: 1080, height: 1920)
        )
    }
}

private extension LayoutEngineTests {
    func transformedVideoBounds(
        videoSize: CGSize,
        transform: CGAffineTransform
    ) -> CGRect {
        CGRect(origin: .zero, size: videoSize)
            .applying(transform)
            .standardized
    }

    func assertRect(
        _ actual: CGRect,
        approximatelyEquals expected: CGRect,
        tolerance: CGFloat = 0.0001
    ) {
        #expect(abs(actual.origin.x - expected.origin.x) <= tolerance)
        #expect(abs(actual.origin.y - expected.origin.y) <= tolerance)
        #expect(abs(actual.size.width - expected.size.width) <= tolerance)
        #expect(abs(actual.size.height - expected.size.height) <= tolerance)
    }
}
