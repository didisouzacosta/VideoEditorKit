import CoreMedia
import Foundation
import Speech
import Testing

@testable import VideoEditorKit

@Suite("AppleSpeechTranscriptionMapperTests")
struct AppleSpeechTranscriptionMapperTests {

    // MARK: - Public Methods

    @Test
    func mapBuildsSegmentsAndWordsFromTimedAttributedText() {
        let mapper = AppleSpeechTranscriptionMapper()
        let results: [AppleSpeechTranscriptionMapper.SourceResult] = [
            .init(
                timeRange(start: 2, end: 4),
                text: timedText([
                    .init(text: "mundo", startTime: 2.1, endTime: 2.6)
                ])
            ),
            .init(
                timeRange(start: 0, end: 1.5),
                text: timedText([
                    .init(text: "ola", startTime: 0, endTime: 0.5),
                    .init(text: " ", startTime: 0.6, endTime: 0.8),
                ])
            ),
        ]

        let result = mapper.map(results)

        #expect(result.segments.count == 2)
        #expect(result.segments[0].text == "ola")
        #expect(result.segments[0].startTime == 0)
        #expect(result.segments[0].endTime == 1.5)
        #expect(result.segments[0].words.count == 1)
        #expect(result.segments[0].words[0].text == "ola")
        #expect(result.segments[1].text == "mundo")
        #expect(result.segments[1].words.count == 1)
        #expect(result.segments[1].words[0].text == "mundo")
    }

    @Test
    func mapSkipsSegmentsThatRemainEmptyAfterNormalization() {
        let mapper = AppleSpeechTranscriptionMapper()
        let results: [AppleSpeechTranscriptionMapper.SourceResult] = [
            .init(
                timeRange(start: 0, end: 1),
                text: AttributedString(" \n ")
            )
        ]

        let result = mapper.map(results)

        #expect(result.segments.isEmpty)
    }

    @Test
    func mapNormalizesInvalidAndNegativeRanges() {
        let mapper = AppleSpeechTranscriptionMapper()
        let results: [AppleSpeechTranscriptionMapper.SourceResult] = [
            .init(
                timeRange(start: 3, end: 1),
                text: timedText([
                    .init(text: "hello", startTime: -1, endTime: -0.5)
                ])
            )
        ]

        let result = mapper.map(results)

        #expect(result.segments.count == 1)
        #expect(result.segments[0].startTime == 0)
        #expect(result.segments[0].endTime == 0)
        #expect(result.segments[0].words.count == 1)
        #expect(result.segments[0].words[0].startTime == 0)
        #expect(result.segments[0].words[0].endTime == 0)
    }

    @Test
    func mapOrdersSegmentsByNormalizedRange() {
        let mapper = AppleSpeechTranscriptionMapper()
        let results: [AppleSpeechTranscriptionMapper.SourceResult] = [
            .init(
                timeRange(start: 4, end: 5),
                text: AttributedString("second")
            ),
            .init(
                timeRange(start: 1, end: 2),
                text: AttributedString("first")
            ),
        ]

        let result = mapper.map(results)

        #expect(result.segments.map(\.text) == ["first", "second"])
    }

    // MARK: - Private Methods

    private func timedText(_ fragments: [TimedTextFragment]) -> AttributedString {
        fragments.reduce(into: AttributedString()) { text, fragment in
            var attributedFragment = AttributedString(fragment.text)
            attributedFragment.audioTimeRange = timeRange(
                start: fragment.startTime,
                end: fragment.endTime
            )
            text += attributedFragment
        }
    }

    private func timeRange(start: Double, end: Double) -> CMTimeRange {
        CMTimeRange(
            start: CMTime(
                seconds: start,
                preferredTimescale: 600
            ),
            end: CMTime(
                seconds: end,
                preferredTimescale: 600
            )
        )
    }

}

private struct TimedTextFragment {

    // MARK: - Public Properties

    let text: String
    let startTime: Double
    let endTime: Double

}
