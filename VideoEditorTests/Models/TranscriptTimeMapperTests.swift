import Testing
import VideoEditorKit

@testable import VideoEditor

@Suite("TranscriptTimeMapperTests")
struct TranscriptTimeMapperTests {

    // MARK: - Public Methods

    @Test
    func timelineTimeScalesSourceTimeByPlaybackRate() {
        let timelineTime = TranscriptTimeMapper.timelineTime(
            fromSourceTime: 24,
            rate: 2
        )

        #expect(abs(timelineTime - 12) < 0.0001)
    }

    @Test
    func sourceTimeScalesTimelineTimeBackToSourceTime() {
        let sourceTime = TranscriptTimeMapper.sourceTime(
            fromTimelineTime: 12,
            rate: 2
        )

        #expect(abs(sourceTime - 24) < 0.0001)
    }

    @Test
    func projectedTimelineRangeClipsTheSegmentToTheTrimmedSourceRange() {
        let projectedRange = TranscriptTimeMapper.projectedTimelineRange(
            sourceRange: 10...40,
            trimRange: 20...60,
            rate: 2
        )

        #expect(projectedRange == 10...20)
    }

    @Test
    func projectedTimelineRangeReturnsNilWhenTheSegmentFallsOutsideTrim() {
        let projectedRange = TranscriptTimeMapper.projectedTimelineRange(
            sourceRange: 5...10,
            trimRange: 20...60,
            rate: 1.5
        )

        #expect(projectedRange == nil)
    }

    @Test
    func remappedTimeMappingPreservesSourceTimesAndClearsInvisibleTimelineTimes() {
        let mapping = TranscriptTimeMapper.remapped(
            .init(
                sourceStartTime: 5,
                sourceEndTime: 10,
                timelineStartTime: 5,
                timelineEndTime: 10
            ),
            trimRange: 20...60,
            rate: 1
        )

        #expect(mapping.sourceStartTime == 5)
        #expect(mapping.sourceEndTime == 10)
        #expect(mapping.timelineStartTime == nil)
        #expect(mapping.timelineEndTime == nil)
    }

    @Test
    func invalidRateFallsBackToRateOne() {
        let projectedRange = TranscriptTimeMapper.projectedTimelineRange(
            sourceRange: 12...20,
            trimRange: 0...50,
            rate: 0
        )

        #expect(projectedRange == 12...20)
    }

}
