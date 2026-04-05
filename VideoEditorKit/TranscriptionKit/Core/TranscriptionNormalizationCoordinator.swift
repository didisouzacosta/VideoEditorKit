//
//  TranscriptionNormalizationCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

struct TranscriptionNormalizationCoordinator {

    // MARK: - Public Methods

    func normalize(
        _ rawResult: RawWhisperTranscriptionResult,
        fallbackDuration: TimeInterval?
    ) -> NormalizedTranscription {
        let normalizedSegments = rawResult.segments
            .map(normalizedSegment(from:))
            .sorted(by: segmentSortOrder)

        return NormalizedTranscription(
            fullText: normalizedFullText(
                rawText: rawResult.text,
                segments: normalizedSegments
            ),
            language: normalizedOptionalText(
                rawResult.language
            ),
            duration: normalizedDuration(
                fallbackDuration: fallbackDuration,
                segments: normalizedSegments
            ),
            segments: normalizedSegments
        )
    }

    // MARK: - Private Methods

    private func normalizedSegment(
        from segment: RawWhisperSegment
    ) -> NormalizedSegment {
        let normalizedWords = segment.words
            .map(normalizedWord(from:))
            .sorted(by: wordSortOrder)
        let normalizedText = normalizedSegmentText(
            rawText: segment.text,
            words: normalizedWords
        )
        let timeRange = normalizedTimeRange(
            startTime: segment.startTime,
            endTime: segment.endTime
        )

        return NormalizedSegment(
            startTime: timeRange.startTime,
            endTime: timeRange.endTime,
            text: normalizedText,
            words: normalizedWords
        )
    }

    private func normalizedWord(
        from word: RawWhisperWord
    ) -> NormalizedWord {
        let timeRange = normalizedTimeRange(
            startTime: word.startTime,
            endTime: word.endTime
        )

        return NormalizedWord(
            startTime: timeRange.startTime,
            endTime: timeRange.endTime,
            text: normalizedText(word.text)
        )
    }

    private func normalizedSegmentText(
        rawText: String,
        words: [NormalizedWord]
    ) -> String {
        let text = normalizedText(rawText)

        guard !text.isEmpty else {
            return
                words
                .map(\.text)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        return text
    }

    private func normalizedFullText(
        rawText: String,
        segments: [NormalizedSegment]
    ) -> String {
        let text = normalizedText(rawText)

        guard !text.isEmpty else {
            return
                segments
                .map(\.text)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        return text
    }

    private func normalizedOptionalText(
        _ text: String?
    ) -> String? {
        let normalized = normalizedText(text)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizedText(
        _ text: String?
    ) -> String {
        (text ?? "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func normalizedDuration(
        fallbackDuration: TimeInterval?,
        segments: [NormalizedSegment]
    ) -> TimeInterval? {
        if let fallbackDuration {
            return max(0, fallbackDuration)
        }

        let lastSegmentEndTime =
            segments
            .map(\.endTime)
            .max()

        return lastSegmentEndTime.map { max(0, $0) }
    }

    private func normalizedTimeRange(
        startTime: TimeInterval,
        endTime: TimeInterval
    ) -> (startTime: TimeInterval, endTime: TimeInterval) {
        let normalizedStartTime = max(0, startTime)
        let normalizedEndTime = max(normalizedStartTime, endTime)

        return (
            startTime: normalizedStartTime,
            endTime: normalizedEndTime
        )
    }

    private func segmentSortOrder(
        _ lhs: NormalizedSegment,
        _ rhs: NormalizedSegment
    ) -> Bool {
        if lhs.startTime == rhs.startTime {
            return lhs.endTime < rhs.endTime
        }

        return lhs.startTime < rhs.startTime
    }

    private func wordSortOrder(
        _ lhs: NormalizedWord,
        _ rhs: NormalizedWord
    ) -> Bool {
        if lhs.startTime == rhs.startTime {
            return lhs.endTime < rhs.endTime
        }

        return lhs.startTime < rhs.startTime
    }

}
