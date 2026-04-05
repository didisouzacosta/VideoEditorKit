import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("TranscriptOverlayLayoutResolverTests")
struct TranscriptOverlayLayoutResolverTests {

    // MARK: - Public Methods

    @Test
    func resolveUsesTheSafeHorizontalInsetAndSizeMultiplier() {
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

        #expect(abs(smallLayout.targetWidth - 508) < 0.0001)
        #expect(abs(mediumLayout.targetWidth - 762) < 0.0001)
        #expect(abs(largeLayout.targetWidth - 1016) < 0.0001)
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
    func resolveReducesFontSizeWhenTheTextGetsMuchLonger() {
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

        #expect(longTextLayout.fontSize < shortTextLayout.fontSize)
    }

}
