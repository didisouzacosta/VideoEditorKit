import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("VideoCropPreviewLayoutTests")
struct VideoCropPreviewLayoutTests {

    // MARK: - Public Methods

    @Test
    func fullPresetRectKeepsViewportAndContentAligned() throws {
        let referenceSize = CGSize(width: 400, height: 200)
        let freeformRect = VideoEditingConfiguration.FreeformRect(
            x: 0.25,
            y: 0,
            width: 0.5,
            height: 1
        )

        let layout = try #require(
            VideoCropPreviewLayout(
                freeformRect: freeformRect,
                in: referenceSize
            )
        )

        #expect(layout.viewportRect == CGRect(x: 100, y: 0, width: 200, height: 200))
        #expect(abs(layout.contentScale - 1) < 0.0001)
        #expect(abs(layout.contentOffset.width) < 0.0001)
        #expect(abs(layout.contentOffset.height) < 0.0001)
    }

    @Test
    func reducedCropRectKeepsTheViewportFixedAndScalesTheContent() throws {
        let referenceSize = CGSize(width: 400, height: 200)
        let freeformRect = VideoEditingConfiguration.FreeformRect(
            x: 0.375,
            y: 0.125,
            width: 0.25,
            height: 0.5
        )

        let layout = try #require(
            VideoCropPreviewLayout(
                freeformRect: freeformRect,
                in: referenceSize
            )
        )

        #expect(layout.viewportRect == CGRect(x: 100, y: 0, width: 200, height: 200))
        #expect(abs(layout.contentScale - 2) < 0.0001)
        #expect(abs(layout.contentOffset.width + 200) < 0.0001)
        #expect(abs(layout.contentOffset.height + 50) < 0.0001)
    }

    @Test
    func gestureTranslationIsConvertedBackToSourceCoordinates() throws {
        let referenceSize = CGSize(width: 400, height: 200)
        let freeformRect = VideoEditingConfiguration.FreeformRect(
            x: 0.375,
            y: 0.125,
            width: 0.25,
            height: 0.5
        )

        let layout = try #require(
            VideoCropPreviewLayout(
                freeformRect: freeformRect,
                in: referenceSize
            )
        )

        let sourceTranslation = layout.sourceTranslation(
            for: CGSize(width: 40, height: -20)
        )

        #expect(abs(sourceTranslation.width + 20) < 0.0001)
        #expect(abs(sourceTranslation.height - 10) < 0.0001)
    }

}
