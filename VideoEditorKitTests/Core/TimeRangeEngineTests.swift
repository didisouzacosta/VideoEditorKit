import Testing
@testable import VideoEditorKit

struct TimeRangeEngineTests {

    @Test func originalPresetUsesFullVideoDuration() {
        let result = TimeRangeEngine.resolve(
            videoDuration: 120,
            currentSelection: 10...50,
            preset: .original
        )

        #expect(result.validRange == 0...120)
        #expect(result.selectedRange == 10...50)
        #expect(result.isVideoTooShort == false)
        #expect(result.exceedsMaximum == false)
    }

    @Test func socialPresetLimitsMaximumDuration() {
        let result = TimeRangeEngine.resolve(
            videoDuration: 120,
            currentSelection: 20...80,
            preset: .instagram
        )

        #expect(result.validRange == 0...90)
        #expect(result.selectedRange == 20...80)
        #expect(result.isVideoTooShort == false)
        #expect(result.exceedsMaximum == true)
    }

    @Test func shortVideoKeepsPreviewFunctionalButMarksPresetAsTooShort() {
        let result = TimeRangeEngine.resolve(
            videoDuration: 2,
            currentSelection: 0...2,
            preset: .tiktok
        )

        #expect(result.validRange == 0...2)
        #expect(result.selectedRange == 0...2)
        #expect(result.isVideoTooShort == true)
        #expect(result.exceedsMaximum == false)
    }

    @Test func invalidSelectionFallsBackToValidRange() {
        let result = TimeRangeEngine.resolve(
            videoDuration: 120,
            currentSelection: 95...110,
            preset: .instagram
        )

        #expect(result.validRange == 0...90)
        #expect(result.selectedRange == 0...90)
    }

    @Test func returningToOriginalDoesNotExpandSelectionAutomatically() {
        let result = TimeRangeEngine.resolve(
            videoDuration: 120,
            currentSelection: 0...90,
            preset: .original
        )

        #expect(result.validRange == 0...120)
        #expect(result.selectedRange == 0...90)
    }

    @Test func clampTimeKeepsScrubInsideSelectedRange() {
        #expect(TimeRangeEngine.clampTime(-5, to: 10...20) == 10)
        #expect(TimeRangeEngine.clampTime(15, to: 10...20) == 15)
        #expect(TimeRangeEngine.clampTime(25, to: 10...20) == 20)
    }
}
