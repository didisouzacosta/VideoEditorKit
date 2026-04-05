//
//  EditorTranscriptMappingCoordinatorTests.swift
//  VideoEditorKitTests
//
//  Created by Codex on 05.04.2026.
//

import Foundation
import Testing

@testable import VideoEditorKit

@Suite
struct EditorTranscriptMappingCoordinatorTests {

    // MARK: - Public Methods

    @Test
    func makeDocumentMapsProviderSegmentsIntoEditableTranscriptContent() {
        let styleID = UUID()
        let segmentID = UUID()
        let wordID = UUID()
        let styles = [
            TranscriptStyle(
                id: styleID,
                name: "Classic",
                fontFamily: "Avenir"
            )
        ]
        let result = VideoTranscriptionResult(
            segments: [
                TranscriptionSegment(
                    id: segmentID,
                    startTime: 8,
                    endTime: 12,
                    text: "hello world",
                    words: [
                        TranscriptionWord(
                            id: wordID,
                            startTime: 8,
                            endTime: 9,
                            text: "hello"
                        )
                    ]
                )
            ]
        )

        let document = EditorTranscriptMappingCoordinator.makeDocument(
            from: result,
            availableStyles: styles,
            overlayPosition: .top,
            overlaySize: .large,
            trimRange: 0...20,
            playbackRate: 2
        )

        #expect(document.availableStyles == styles)
        #expect(document.overlayPosition == .top)
        #expect(document.overlaySize == .large)
        #expect(document.segments.count == 1)
        #expect(document.segments.first?.id == segmentID)
        #expect(document.segments.first?.originalText == "hello world")
        #expect(document.segments.first?.editedText == "hello world")
        #expect(document.segments.first?.styleID == nil)
        #expect(document.segments.first?.timeMapping.sourceRange == 8...12)
        #expect(document.segments.first?.timeMapping.timelineRange == 4...6)
        #expect(document.segments.first?.words.count == 1)
        #expect(document.segments.first?.words.first?.id == wordID)
        #expect(document.segments.first?.words.first?.originalText == "hello")
        #expect(document.segments.first?.words.first?.editedText == "hello")
        #expect(document.segments.first?.words.first?.timeMapping.timelineRange == 4...4.5)
    }

    @Test
    func makeDocumentKeepsSourceTimingButClearsTimelineForSegmentsOutsideTrim() {
        let result = VideoTranscriptionResult(
            segments: [
                TranscriptionSegment(
                    id: UUID(),
                    startTime: 2,
                    endTime: 4,
                    text: "outside trim"
                )
            ]
        )

        let document = EditorTranscriptMappingCoordinator.makeDocument(
            from: result,
            trimRange: 8...20,
            playbackRate: 1.5
        )

        #expect(document.segments.count == 1)
        #expect(document.segments.first?.timeMapping.sourceRange == 2...4)
        #expect(document.segments.first?.timeMapping.timelineRange == nil)
        #expect(document.segments.first?.editedText == "outside trim")
    }

}
