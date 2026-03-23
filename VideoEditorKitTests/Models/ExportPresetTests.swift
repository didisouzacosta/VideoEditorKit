import CoreGraphics
import Testing
@testable import VideoEditorKit

@MainActor
struct ExportPresetTests {

    @Test func titlesMatchToolbarLabels() {
        #expect(ExportPreset.original.title == "Original")
        #expect(ExportPreset.instagram.title == "Instagram")
        #expect(ExportPreset.youtube.title == "YouTube")
        #expect(ExportPreset.tiktok.title == "TikTok")
    }

    @Test func durationRulesMatchPlan() {
        #expect(ExportPreset.original.minDuration == 0)
        #expect(ExportPreset.original.maxDuration == .infinity)

        #expect(ExportPreset.instagram.minDuration == 3)
        #expect(ExportPreset.instagram.maxDuration == 90)

        #expect(ExportPreset.youtube.minDuration == 1)
        #expect(ExportPreset.youtube.maxDuration == 60)

        #expect(ExportPreset.tiktok.minDuration == 3)
        #expect(ExportPreset.tiktok.maxDuration == 180)
    }

    @Test func originalUsesSourceVideoSizeAndNoAspectRatio() {
        let sourceSize = CGSize(width: 1920, height: 1080)

        #expect(ExportPreset.original.resolve(videoSize: sourceSize) == sourceSize)
        #expect(ExportPreset.original.aspectRatio == nil)
    }

    @Test func socialPresetsUseVerticalCanvas() {
        let sourceSize = CGSize(width: 1920, height: 1080)
        let expectedSize = CGSize(width: 1080, height: 1920)

        #expect(ExportPreset.instagram.resolve(videoSize: sourceSize) == expectedSize)
        #expect(ExportPreset.youtube.resolve(videoSize: sourceSize) == expectedSize)
        #expect(ExportPreset.tiktok.resolve(videoSize: sourceSize) == expectedSize)
    }

    @Test func socialPresetsShareNineBySixteenAspectRatio() {
        let expectedAspectRatio = CGFloat(9.0 / 16.0)

        #expect(abs((ExportPreset.instagram.aspectRatio ?? 0) - expectedAspectRatio) < 0.0001)
        #expect(abs((ExportPreset.youtube.aspectRatio ?? 0) - expectedAspectRatio) < 0.0001)
        #expect(abs((ExportPreset.tiktok.aspectRatio ?? 0) - expectedAspectRatio) < 0.0001)
    }
}
