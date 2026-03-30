import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("VideoCropFormatPresetTests")
struct VideoCropFormatPresetTests {

    // MARK: - Public Methods

    @Test
    func originalPresetDoesNotCreateACropRect() {
        let cropRect = VideoCropFormatPreset.original.makeFreeformRect(
            for: CGSize(width: 1920, height: 1080)
        )

        #expect(cropRect == nil)
    }

    @Test
    func verticalPresetCreatesCentered9x16CropForLandscapeVideo() throws {
        let cropRect = try #require(
            VideoCropFormatPreset.vertical9x16.makeFreeformRect(
                for: CGSize(width: 1920, height: 1080)
            )
        )

        #expect(abs(cropRect.x - 0.341796875) < 0.0001)
        #expect(abs(cropRect.y - 0) < 0.0001)
        #expect(abs(cropRect.width - 0.31640625) < 0.0001)
        #expect(abs(cropRect.height - 1) < 0.0001)
    }

    @Test
    func verticalPresetMatchesItsGeneratedCropRect() {
        let referenceSize = CGSize(width: 1920, height: 1080)
        let cropRect = VideoCropFormatPreset.vertical9x16.makeFreeformRect(
            for: referenceSize
        )

        #expect(
            VideoCropFormatPreset.vertical9x16.matches(
                cropRect,
                in: referenceSize
            )
        )
    }

    @Test
    func verticalPresetMatchesFullFrameOnNativeVerticalVideo() {
        let referenceSize = CGSize(width: 1080, height: 1920)
        let cropRect = VideoEditingConfiguration.FreeformRect(
            x: 0,
            y: 0,
            width: 1,
            height: 1
        )

        #expect(
            VideoCropFormatPreset.vertical9x16.matches(
                cropRect,
                in: referenceSize
            )
        )
    }

}
