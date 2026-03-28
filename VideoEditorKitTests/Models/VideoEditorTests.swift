import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("VideoEditorTests")
struct VideoEditorTests {

    // MARK: - Public Methods

    @Test
    func resolvedCropRectConvertsNormalizedGeometryIntoRenderCoordinates() {
        let cropRect = VideoEditor.resolvedCropRect(
            for: .init(
                x: 0.1,
                y: 0.2,
                width: 0.5,
                height: 0.4
            ),
            in: CGSize(width: 1000, height: 500)
        )

        #expect(cropRect == CGRect(x: 100, y: 100, width: 500, height: 200))
    }

    @Test
    func resolvedCropRectClampsOutOfBoundsValuesToTheVisibleFrame() {
        let cropRect = VideoEditor.resolvedCropRect(
            for: .init(
                x: -0.2,
                y: 0.85,
                width: 1.4,
                height: 0.5
            ),
            in: CGSize(width: 1000, height: 500)
        )

        #expect(cropRect == CGRect(x: 0, y: 424, width: 1000, height: 76))
    }

}
