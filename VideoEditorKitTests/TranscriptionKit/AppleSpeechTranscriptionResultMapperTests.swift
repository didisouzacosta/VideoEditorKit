import CoreMedia
import Foundation
import Speech
import Testing

@testable import VideoEditorKit

@Suite("AppleSpeechTranscriptionResultMapperTests")
struct AppleSpeechTranscriptionResultMapperTests {

    // MARK: - Public Methods

    @Test
    func mapBuildsSegmentsAndTokenizedWordsFromAttributedRuns() {
        let mapper = AppleSpeechTranscriptionResultMapper()
        let result = mapper.map(
            [
                AppleSpeechTranscriptionUnit(
                    startTime: 0,
                    endTime: 1.3,
                    transcription: makeAttributedTranscription(
                        text: "ola mundo",
                        timedTokens: [
                            ("ola", 0, 0.5),
                            ("mundo", 0.7, 1.3),
                        ]
                    )
                )
            ]
        )

        #expect(result.segments.count == 1)
        #expect(result.segments[0].text == "ola mundo")
        #expect(result.segments[0].words.map(\.text) == ["ola", "mundo"])
        #expect(result.segments[0].words[0].startTime == 0)
        #expect(result.segments[0].words[1].endTime == 1.3)
    }

    @Test
    func mapSkipsWordExtractionWhenTheTimedRunContainsWhitespace() {
        let mapper = AppleSpeechTranscriptionResultMapper()
        let result = mapper.map(
            [
                AppleSpeechTranscriptionUnit(
                    startTime: 0,
                    endTime: 2,
                    transcription: makeAttributedTranscription(
                        text: "ola mundo",
                        timedTokens: [
                            ("ola mundo", 0, 2)
                        ]
                    )
                )
            ]
        )

        #expect(result.segments.count == 1)
        #expect(result.segments[0].text == "ola mundo")
        #expect(result.segments[0].words.isEmpty)
    }

    @Test
    func mapSortsSegmentsByTimeAndSkipsBlankTranscriptions() {
        let mapper = AppleSpeechTranscriptionResultMapper()
        let result = mapper.map(
            [
                AppleSpeechTranscriptionUnit(
                    startTime: 5,
                    endTime: 6,
                    transcription: makeAttributedTranscription(
                        text: " segundo ",
                        timedTokens: []
                    )
                ),
                AppleSpeechTranscriptionUnit(
                    startTime: 0,
                    endTime: 1,
                    transcription: makeAttributedTranscription(
                        text: "   ",
                        timedTokens: []
                    )
                ),
                AppleSpeechTranscriptionUnit(
                    startTime: 1,
                    endTime: 2,
                    transcription: makeAttributedTranscription(
                        text: " primeiro ",
                        timedTokens: []
                    )
                ),
            ]
        )

        #expect(result.segments.map(\.text) == ["primeiro", "segundo"])
        #expect(result.segments.map(\.startTime) == [1, 5])
    }

    // MARK: - Private Methods

    private func makeAttributedTranscription(
        text: String,
        timedTokens: [(text: String, startTime: Double, endTime: Double)]
    ) -> AttributedString {
        var attributedText = AttributedString(text)

        for timedToken in timedTokens {
            guard let tokenRange = attributedText.range(of: timedToken.text) else { continue }

            attributedText[tokenRange].audioTimeRange = CMTimeRange(
                start: CMTime(seconds: timedToken.startTime, preferredTimescale: 600),
                duration: CMTime(
                    seconds: timedToken.endTime - timedToken.startTime,
                    preferredTimescale: 600
                )
            )
        }

        return attributedText
    }

}
