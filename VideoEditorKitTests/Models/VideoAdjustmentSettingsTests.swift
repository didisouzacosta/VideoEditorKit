import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct VideoAdjustmentSettingsTests {

    @Test func defaultsAreNeutralAndDoNotChangeOutputDuration() {
        let settings = VideoAdjustmentSettings()

        #expect(settings.playbackRate == 1)
        #expect(settings.rotation == .degrees0)
        #expect(settings.isMirrored == false)
        #expect(settings.filterName == nil)
        #expect(settings.colorCorrection.isIdentity)
        #expect(settings.frameStyle == nil)
        #expect(settings.outputDuration(for: 2...8) == 6)
    }

    @Test func outputDurationUsesPlaybackRate() {
        let settings = VideoAdjustmentSettings(playbackRate: 2)

        #expect(settings.outputDuration(for: 3...9) == 3)
    }

    @Test func playbackRateInitializerNormalizesInvalidValuesToNeutral() {
        #expect(VideoAdjustmentSettings(playbackRate: -3).playbackRate == 1)
        #expect(VideoAdjustmentSettings(playbackRate: 0).playbackRate == 1)
        #expect(VideoAdjustmentSettings(playbackRate: .infinity).playbackRate == 1)
    }

    @Test func filterNameTrimsWhitespaceAndDropsEmptyValue() {
        #expect(VideoAdjustmentSettings(filterName: "  CISepiaTone  ").filterName == "CISepiaTone")
        #expect(VideoAdjustmentSettings(filterName: "   ").filterName == nil)
    }

    @Test func rotationRotatesClockwiseInQuarterTurns() {
        #expect(VideoRotation.degrees0.rotatedClockwise() == .degrees90)
        #expect(VideoRotation.degrees90.rotatedClockwise() == .degrees180)
        #expect(VideoRotation.degrees180.rotatedClockwise() == .degrees270)
        #expect(VideoRotation.degrees270.rotatedClockwise() == .degrees0)
    }

    @Test func colorCorrectionClampsEachChannelIntoSupportedRange() {
        let correction = VideoColorCorrection(
            brightness: 2,
            contrast: -2,
            saturation: 0.4
        )

        #expect(correction.brightness == 1)
        #expect(correction.contrast == -1)
        #expect(correction.saturation == 0.4)
        #expect(correction.isIdentity == false)
    }

    @Test func frameStyleClampsScaleIntoSupportedRange() {
        let small = VideoFrameStyle(backgroundColor: .white, scale: 0.1)
        let large = VideoFrameStyle(backgroundColor: .black, scale: 2)

        #expect(small.scale == 0.5)
        #expect(large.scale == 1)
    }
}
