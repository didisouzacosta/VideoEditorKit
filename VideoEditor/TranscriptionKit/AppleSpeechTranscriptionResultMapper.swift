//
//  AppleSpeechTranscriptionResultMapper.swift
//  VideoEditorKit
//
//  Created by Codex on 08.04.2026.
//

import CoreMedia
import Foundation
import Speech
import VideoEditorKit

struct AppleSpeechTranscriptionUnit: Hashable, Sendable {

    // MARK: - Public Properties

    let startTime: Double
    let endTime: Double
    let transcription: AttributedString

}

struct AppleSpeechTranscriptionResultMapper {

    // MARK: - Public Methods

    func map(_ units: [AppleSpeechTranscriptionUnit]) -> VideoTranscriptionResult {
        var segments = [TranscriptionSegment]()

        for unit in units.sorted(by: unitSortComparator(_:_:)) {
            let words = mappedWords(from: unit.transcription)
            let text = resolvedSegmentText(
                unit.transcription,
                words: words
            )

            guard text.isEmpty == false else { continue }

            segments.append(
                TranscriptionSegment(
                    id: UUID(),
                    startTime: normalizedStartTime(for: unit.startTime),
                    endTime: normalizedEndTime(
                        startTime: unit.startTime,
                        endTime: unit.endTime
                    ),
                    text: text,
                    words: words
                )
            )
        }

        return VideoTranscriptionResult(segments: segments)
    }

    // MARK: - Private Methods

    private func mappedWords(
        from transcription: AttributedString
    ) -> [TranscriptionWord] {
        var words = [TranscriptionWord]()

        for run in transcription.runs {
            guard let audioTimeRange = run.audioTimeRange else { continue }

            let runText = String(transcription.characters[run.range])
            let text = normalizedTokenText(runText)
            guard text.isEmpty == false else { continue }

            words.append(
                TranscriptionWord(
                    id: UUID(),
                    startTime: normalizedStartTime(for: audioTimeRange.start.seconds),
                    endTime: normalizedEndTime(
                        startTime: audioTimeRange.start.seconds,
                        endTime: CMTimeRangeGetEnd(audioTimeRange).seconds
                    ),
                    text: text
                )
            )
        }

        return words.sorted(by: wordSortComparator(_:_:))
    }

    private func resolvedSegmentText(
        _ transcription: AttributedString,
        words: [TranscriptionWord]
    ) -> String {
        let normalizedSegmentText = normalizedText(
            String(transcription.characters)
        )
        guard normalizedSegmentText.isEmpty else { return normalizedSegmentText }

        return normalizedText(
            words
                .map(\.text)
                .joined(separator: " ")
        )
    }

    private func normalizedTokenText(_ text: String) -> String {
        let normalizedText = normalizedText(text)
        guard normalizedText.isEmpty == false else { return "" }
        guard normalizedText.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return "" }
        return normalizedText
    }

    private func normalizedText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private func normalizedStartTime(for time: Double) -> Double {
        max(time, 0)
    }

    private func normalizedEndTime(
        startTime: Double,
        endTime: Double
    ) -> Double {
        let resolvedStartTime = normalizedStartTime(for: startTime)
        return max(normalizedStartTime(for: endTime), resolvedStartTime)
    }

    private func unitSortComparator(
        _ lhs: AppleSpeechTranscriptionUnit,
        _ rhs: AppleSpeechTranscriptionUnit
    ) -> Bool {
        if lhs.startTime != rhs.startTime {
            return lhs.startTime < rhs.startTime
        }

        return lhs.endTime < rhs.endTime
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
