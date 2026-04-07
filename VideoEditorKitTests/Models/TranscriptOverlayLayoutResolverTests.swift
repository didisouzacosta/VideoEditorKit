import CoreGraphics
import Foundation
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

        #expect(abs((1920 - portraitLayout.overlayFrame.maxY) - 16) < 0.0001)
        #expect(abs((1080 - squareLayout.overlayFrame.maxY) - 16) < 0.0001)
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

        #expect(abs((480 - previewLayout.overlayFrame.maxY) - 4) < 0.0001)
        #expect(previewLayout.fontSize > 0)
    }

    @Test
    func resolveMeasuresTheRealTextHeightForCenteredMultilineSegments() {
        let layout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .center,
            selectedSize: .medium,
            text: """
                Edmure, da criacao do universo ao surgimento
                dos elfos e homens, conheca a saga das
                Silmarils
                """
        )

        #expect(abs(layout.overlayFrame.midY - 960) < 0.0001)
        #expect(layout.overlayFrame.height > 0)
    }

    @Test
    func resolveUsesUniformSixteenPointInsetsForBottomOverlaysOnASocialCanvas() {
        let layout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "Bottom aligned caption"
        )

        #expect(abs(layout.overlayFrame.minX - 16) < 0.0001)
        #expect(abs((1080 - layout.overlayFrame.maxX) - 16) < 0.0001)
        #expect(abs((1920 - layout.overlayFrame.maxY) - 16) < 0.0001)
    }

    @Test
    func resolveAppliesInternalPaddingToTheTranscriptTextFrame() {
        let layout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "Bottom aligned caption"
        )

        #expect(abs(layout.textFrame.minX - 28) < 0.0001)
        #expect(abs((1080 - layout.textFrame.maxX) - 28) < 0.0001)
        #expect(abs(layout.textFrame.minY - (layout.overlayFrame.minY + 16)) < 0.0001)
        #expect(abs(layout.overlayFrame.maxY - layout.textFrame.maxY - 16) < 0.0001)
    }

    @Test
    func resolveMeasuresMultilineHeightUsingThePaddedTextWidth() {
        let layout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text:
                "Edmure, da criacao do universo ao surgimento dos elfos e homens, conheca a saga das Silmarils"
        )

        let measuredTextHeight = TranscriptTextStyleResolver.measuredTextHeight(
            text: "Edmure, da criacao do universo ao surgimento dos elfos e homens, conheca a saga das Silmarils",
            style: TranscriptStyle(
                id: UUID(uuidString: "E5A04D11-329A-4C8E-B266-1E6A60A6F9F9") ?? UUID(),
                name: "Default",
                fontFamily: "SF Pro Rounded"
            ),
            fontSize: layout.fontSize,
            targetWidth: layout.textFrame.width
        )

        #expect(abs(layout.textFrame.height - measuredTextHeight) < 0.0001)
        #expect(abs(layout.overlayFrame.height - (measuredTextHeight + 32)) < 0.0001)
        #expect(abs((1920 - layout.overlayFrame.maxY) - 16) < 0.0001)
    }

    @Test
    func resolveUsesUniformSixteenPointInsetsForTopOverlaysOnASocialCanvas() {
        let layout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .top,
            selectedSize: .medium,
            text: "Top aligned caption"
        )

        #expect(abs(layout.overlayFrame.minX - 16) < 0.0001)
        #expect(abs((1080 - layout.overlayFrame.maxX) - 16) < 0.0001)
        #expect(abs(layout.overlayFrame.minY - 16) < 0.0001)
    }

    @Test
    func resolveKeepsBottomAnchorAtSixteenPointsForShortAndLongSegments() {
        let shortLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text: "Short caption"
        )
        let longLayout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: 1080,
            videoHeight: 1920,
            selectedPosition: .bottom,
            selectedSize: .medium,
            text:
                "This is a much longer transcript segment that should still remain anchored to the bottom edge with the same sixteen point margin even when the text expands into multiple visual lines in the social preset canvas."
        )

        #expect(abs((1920 - shortLayout.overlayFrame.maxY) - 16) < 0.0001)
        #expect(abs((1920 - longLayout.overlayFrame.maxY) - 16) < 0.0001)
        #expect(abs(shortLayout.overlayFrame.minX - 16) < 0.0001)
        #expect(abs(longLayout.overlayFrame.minX - 16) < 0.0001)
    }

}
