import CoreGraphics
import Testing
@testable import VideoEditorKit

struct CaptionSafeFrameResolverTests {

    @Test func originalPresetProducesExpectedInsetFrame() {
        let renderSize = CGSize(width: 1920, height: 1080)

        let safeFrame = CaptionSafeFrameResolver.resolve(
            renderSize: renderSize,
            safeArea: ExportPreset.original.captionSafeArea
        )

        #expect(safeFrame == CGRect(x: 24, y: 24, width: 1872, height: 1032))
    }

    @Test func socialPresetProducesExpectedSafeFrame() {
        let renderSize = CGSize(width: 1080, height: 1920)

        let safeFrame = CaptionSafeFrameResolver.resolve(
            renderSize: renderSize,
            safeArea: ExportPreset.tiktok.captionSafeArea
        )

        #expect(safeFrame == CGRect(x: 32, y: 100, width: 968, height: 1520))
    }

    @Test func oversizedInsetsClampDegenerateFrameToZeroDimensions() {
        let safeFrame = CaptionSafeFrameResolver.resolve(
            renderSize: CGSize(width: 100, height: 80),
            safeArea: CaptionSafeArea(
                topInset: 60,
                leftInset: 70,
                bottomInset: 40,
                rightInset: 50
            )
        )

        #expect(safeFrame == CGRect(x: 70, y: 60, width: 0, height: 0))
    }
}
