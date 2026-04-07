import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("TranscriptOverlayLayoutResolverTests")
struct TranscriptOverlayLayoutResolverTests {

    // MARK: - Public Methods

    @Test
    func resolveUsesTheFullCanvasWidthForEveryOverlaySize() {
        let smallLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .small,
            text: "Short line"
        )
        let mediumLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "Short line"
        )
        let largeLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .large,
            text: "Short line"
        )

        #expect(abs(smallLayout.targetWidth - 1048) < 0.0001)
        #expect(abs(mediumLayout.targetWidth - 1048) < 0.0001)
        #expect(abs(largeLayout.targetWidth - 1048) < 0.0001)
    }

    @Test
    func resolveMovesTheOverlayAcrossTheExpectedVerticalZones() {
        let topLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .top,
            selectedSize: .medium,
            text: "Overlay"
        )
        let centerLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .center,
            selectedSize: .medium,
            text: "Overlay"
        )
        let bottomLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "Overlay"
        )

        #expect(topLayout.overlayFrame.midY < centerLayout.overlayFrame.midY)
        #expect(centerLayout.overlayFrame.midY < bottomLayout.overlayFrame.midY)
    }

    @Test
    func resolveDoesNotIncreaseFontSizeWhenTheTextGetsMuchLonger() {
        let shortTextLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "Short line"
        )
        let longTextLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "This is a much longer subtitle line that should force the resolver to shrink the font size"
        )

        #expect(longTextLayout.fontSize <= shortTextLayout.fontSize)
    }

    @Test
    func resolveKeepsBottomAlignedOverlaysAnchoredToTheBottomInsetAcrossPresetChanges() {
        let portraitLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "Bottom aligned caption"
        )
        let squareLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1080,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "Bottom aligned caption"
        )

        #expect(abs((1920 - portraitLayout.overlayFrame.maxY) - 19.2) < 0.0001)
        #expect(abs((1080 - squareLayout.overlayFrame.maxY) - 10.8) < 0.0001)
    }

    @Test
    func resolveExpandsTheOverlayHeightToFitAdditionalWrappedLines() {
        let shortTextLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 720,
            videoHeight: 1280,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "Short line"
        )
        let multilineLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 720,
            videoHeight: 1280,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text:
                "This transcript segment is intentionally long enough to wrap into multiple lines and needs extra vertical space to stay fully visible inside the preview."
        )

        #expect(multilineLayout.overlayFrame.height > shortTextLayout.overlayFrame.height)
    }

    @Test
    func resolvePreviewLayoutScalesExportAnchoringIntoTheVisiblePreviewCanvas() {
        let previewLayout = TranscriptOverlayLayoutResolver.resolvePreviewLayout(
            exportCanvasSize: CGSize(width: 1080, height: 1920),
            previewCanvasSize: CGSize(width: 270, height: 480),
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "Bottom aligned caption"
        )

        #expect(abs((480 - previewLayout.overlayFrame.maxY) - 4.8) < 0.0001)
        #expect(previewLayout.fontSize > 0)
    }

}
