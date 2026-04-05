//
//  EditorTranscriptMappingCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

enum EditorTranscriptMappingCoordinator {

    // MARK: - Public Methods

    static func makeDocument(
        from result: VideoTranscriptionResult,
        availableStyles: [TranscriptStyle] = [],
        overlayPosition: TranscriptOverlayPosition = .bottom,
        overlaySize: TranscriptOverlaySize = .medium,
        trimRange: ClosedRange<Double>,
        playbackRate: Float
    ) -> TranscriptDocument {
        TranscriptDocument(
            segments: result.segments.map {
                makeEditableSegment(
                    from: $0,
                    trimRange: trimRange,
                    playbackRate: playbackRate
                )
            },
            availableStyles: availableStyles,
            overlayPosition: overlayPosition,
            overlaySize: overlaySize
        )
    }

    // MARK: - Private Methods

    private static func makeEditableSegment(
        from segment: TranscriptionSegment,
        trimRange: ClosedRange<Double>,
        playbackRate: Float
    ) -> EditableTranscriptSegment {
        EditableTranscriptSegment(
            id: segment.id,
            timeMapping: makeTimeMapping(
                startTime: segment.startTime,
                endTime: segment.endTime,
                trimRange: trimRange,
                playbackRate: playbackRate
            ),
            originalText: segment.text,
            editedText: segment.text,
            words: segment.words.map {
                makeEditableWord(
                    from: $0,
                    trimRange: trimRange,
                    playbackRate: playbackRate
                )
            },
            styleID: nil
        )
    }

    private static func makeEditableWord(
        from word: TranscriptionWord,
        trimRange: ClosedRange<Double>,
        playbackRate: Float
    ) -> EditableTranscriptWord {
        EditableTranscriptWord(
            id: word.id,
            timeMapping: makeTimeMapping(
                startTime: word.startTime,
                endTime: word.endTime,
                trimRange: trimRange,
                playbackRate: playbackRate
            ),
            originalText: word.text,
            editedText: word.text
        )
    }

    private static func makeTimeMapping(
        startTime: Double,
        endTime: Double,
        trimRange: ClosedRange<Double>,
        playbackRate: Float
    ) -> TranscriptTimeMapping {
        TranscriptTimeMapper.remapped(
            TranscriptTimeMapping(
                sourceStartTime: startTime,
                sourceEndTime: endTime,
                timelineStartTime: nil,
                timelineEndTime: nil
            ),
            trimRange: trimRange,
            rate: playbackRate
        )
    }

}
