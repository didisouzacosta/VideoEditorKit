import CoreMedia
import Foundation
import Speech

struct AppleSpeechTranscriptionMapper {

    struct SourceResult: Sendable {

        // MARK: - Public Properties

        let range: CMTimeRange
        let text: AttributedString
        let alternatives: [AttributedString]

        // MARK: - Initializer

        init(
            _ range: CMTimeRange,
            text: AttributedString,
            alternatives: [AttributedString] = []
        ) {
            self.range = range
            self.text = text
            self.alternatives = alternatives
        }

        init(_ result: SpeechTranscriber.Result) {
            self.init(
                result.range,
                text: result.text,
                alternatives: result.alternatives
            )
        }

    }

    // MARK: - Public Methods

    func map(_ results: [SpeechTranscriber.Result]) -> VideoTranscriptionResult {
        map(results.map(SourceResult.init))
    }

    func map(_ results: [SourceResult]) -> VideoTranscriptionResult {
        VideoTranscriptionResult(
            segments:
                results
                .sorted(by: resultSortComparator(_:_:))
                .compactMap(mappedSegment(from:))
        )
    }

    // MARK: - Private Methods

    private func mappedSegment(from result: SourceResult) -> TranscriptionSegment? {
        let words = normalizedWords(from: result.text)
        let text = resolvedSegmentText(
            result.text,
            words: words
        )

        guard !text.isEmpty else { return nil }

        let bounds = normalizedBounds(from: result.range)
        return TranscriptionSegment(
            id: UUID(),
            startTime: bounds.startTime,
            endTime: bounds.endTime,
            text: text,
            words: words
        )
    }

    private func normalizedWords(from text: AttributedString) -> [TranscriptionWord] {
        text.runs
            .compactMap { run in
                guard let audioTimeRange = run.audioTimeRange else { return nil }

                let wordText = normalizedText(
                    String(text[run.range].characters)
                )

                guard !wordText.isEmpty else { return nil }

                let bounds = normalizedBounds(from: audioTimeRange)
                return TranscriptionWord(
                    id: UUID(),
                    startTime: bounds.startTime,
                    endTime: bounds.endTime,
                    text: wordText
                )
            }
            .sorted(by: wordSortComparator(_:_:))
    }

    private func resolvedSegmentText(
        _ text: AttributedString,
        words: [TranscriptionWord]
    ) -> String {
        let normalizedSegmentText = normalizedText(
            String(text.characters)
        )

        guard normalizedSegmentText.isEmpty else { return normalizedSegmentText }

        return normalizedText(
            words
                .map(\.text)
                .joined(separator: " ")
        )
    }

    private func normalizedBounds(from range: CMTimeRange) -> (startTime: Double, endTime: Double) {
        let startTime = normalizedTime(range.start)
        let endTime = max(
            normalizedTime(range.end),
            startTime
        )

        return (startTime, endTime)
    }

    private func normalizedTime(_ time: CMTime) -> Double {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite else { return 0 }

        return max(seconds, 0)
    }

    private func normalizedText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func resultSortComparator(
        _ lhs: SourceResult,
        _ rhs: SourceResult
    ) -> Bool {
        let lhsBounds = normalizedBounds(from: lhs.range)
        let rhsBounds = normalizedBounds(from: rhs.range)

        if lhsBounds.startTime != rhsBounds.startTime {
            return lhsBounds.startTime < rhsBounds.startTime
        }

        return lhsBounds.endTime < rhsBounds.endTime
    }

    private func wordSortComparator(
        _ lhs: TranscriptionWord,
        _ rhs: TranscriptionWord
    ) -> Bool {
        if lhs.startTime != rhs.startTime {
            return lhs.startTime < rhs.startTime
        }

        return lhs.endTime < rhs.endTime
    }

}
