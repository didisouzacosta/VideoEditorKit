import Foundation
import Testing

@testable import VideoEditorKit

@Suite("TranscriptWordEditingCoordinatorTests")
struct TranscriptWordEditingCoordinatorTests {

    // MARK: - Public Methods

    @Test
    func reconcileWordsUpdatesEditableWordTextsWhenTheEditedSegmentKeepsTheSameWordCount() {
        let words = [
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0,
                    sourceEndTime: 0.5,
                    timelineStartTime: 0,
                    timelineEndTime: 0.5
                ),
                originalText: "hello",
                editedText: "hello"
            ),
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0.5,
                    sourceEndTime: 1,
                    timelineStartTime: 0.5,
                    timelineEndTime: 1
                ),
                originalText: "world",
                editedText: "world"
            ),
        ]

        let reconciledWords = TranscriptWordEditingCoordinator.reconcileWords(
            words,
            with: "Hello, world!"
        )

        #expect(reconciledWords?.map(\.editedText) == ["Hello,", "world!"])
    }

    @Test
    func reconcileWordsMergesStandalonePunctuationIntoTheAdjacentWordBlocks() {
        let words = [
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0,
                    sourceEndTime: 0.5,
                    timelineStartTime: 0,
                    timelineEndTime: 0.5
                ),
                originalText: "hello",
                editedText: "hello"
            ),
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0.5,
                    sourceEndTime: 1,
                    timelineStartTime: 0.5,
                    timelineEndTime: 1
                ),
                originalText: "world",
                editedText: "world"
            ),
        ]

        let reconciledWords = TranscriptWordEditingCoordinator.reconcileWords(
            words,
            with: "\" Hello , world !"
        )

        #expect(reconciledWords?.map(\.editedText) == ["\"Hello,", "world!"])
    }

    @Test
    func reconcileWordsKeepsHighlightableBlocksWhenANewWordIsInsertedBetweenMatchedWords() {
        let words = [
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0,
                    sourceEndTime: 0.5,
                    timelineStartTime: 0,
                    timelineEndTime: 0.5
                ),
                originalText: "hello",
                editedText: "hello"
            ),
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0.5,
                    sourceEndTime: 1,
                    timelineStartTime: 0.5,
                    timelineEndTime: 1
                ),
                originalText: "world",
                editedText: "world"
            ),
        ]

        let reconciledWords = TranscriptWordEditingCoordinator.reconcileWords(
            words,
            with: "hello brave world"
        )

        #expect(reconciledWords?.map(\.editedText) == ["hello brave", "world"])
    }

    @Test
    func reconcileWordsAllowsRemovingATrailingWordWithoutDroppingAllWordBlocks() {
        let words = [
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0,
                    sourceEndTime: 0.5,
                    timelineStartTime: 0,
                    timelineEndTime: 0.5
                ),
                originalText: "hello",
                editedText: "hello"
            ),
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0.5,
                    sourceEndTime: 1,
                    timelineStartTime: 0.5,
                    timelineEndTime: 1
                ),
                originalText: "world",
                editedText: "world"
            ),
        ]

        let reconciledWords = TranscriptWordEditingCoordinator.reconcileWords(
            words,
            with: "hello"
        )

        #expect(reconciledWords?.map(\.editedText) == ["hello", ""])
    }

    @Test
    func reconcileWordsReturnsNilWhenTheEditedSegmentBecomesEmpty() {
        let words = [
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0,
                    sourceEndTime: 0.5,
                    timelineStartTime: 0,
                    timelineEndTime: 0.5
                ),
                originalText: "hello",
                editedText: "hello"
            ),
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0.5,
                    sourceEndTime: 1,
                    timelineStartTime: 0.5,
                    timelineEndTime: 1
                ),
                originalText: "world",
                editedText: "world"
            ),
        ]

        let reconciledWords = TranscriptWordEditingCoordinator.reconcileWords(
            words,
            with: "   "
        )

        #expect(reconciledWords == nil)
    }

    @Test
    func reconcileWordsRedistributesTokensAcrossExistingWordTimingsWhenTheSentenceIsCompletelyRewritten() {
        let words = [
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0,
                    sourceEndTime: 0.5,
                    timelineStartTime: 0,
                    timelineEndTime: 0.5
                ),
                originalText: "hello",
                editedText: "hello"
            ),
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0.5,
                    sourceEndTime: 1,
                    timelineStartTime: 0.5,
                    timelineEndTime: 1
                ),
                originalText: "world",
                editedText: "world"
            ),
        ]

        let reconciledWords = TranscriptWordEditingCoordinator.reconcileWords(
            words,
            with: "greetings from another realm"
        )

        #expect(reconciledWords?.map(\.editedText) == ["greetings from", "another realm"])
    }

    @Test
    func reconcileWordsKeepsTimedWordBlocksWhenOnlyOneOriginalWordStillMatchesInALongerRewrite() {
        let words = [
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0,
                    sourceEndTime: 0.5,
                    timelineStartTime: 0,
                    timelineEndTime: 0.5
                ),
                originalText: "hello",
                editedText: "hello"
            ),
            EditableTranscriptWord(
                id: UUID(),
                timeMapping: .init(
                    sourceStartTime: 0.5,
                    sourceEndTime: 1,
                    timelineStartTime: 0.5,
                    timelineEndTime: 1
                ),
                originalText: "world",
                editedText: "world"
            ),
        ]

        let reconciledWords = TranscriptWordEditingCoordinator.reconcileWords(
            words,
            with: "greetings brave world"
        )

        #expect(reconciledWords?.map(\.editedText) == ["greetings brave", "world"])
    }

    @Test
    func resolvedWordsCreatesSyntheticTimingBlocksWhenTheSegmentHasNoPerWordTimings() {
        let segment = EditableTranscriptSegment(
            id: UUID(),
            timeMapping: .init(
                sourceStartTime: 10,
                sourceEndTime: 14,
                timelineStartTime: 2,
                timelineEndTime: 6
            ),
            originalText: "hello world",
            editedText: "greetings brave world"
        )

        let resolvedWords = TranscriptWordEditingCoordinator.resolvedWords(
            for: segment
        )
        let timelineRanges = resolvedWords.compactMap(\.timeMapping.timelineRange)

        #expect(resolvedWords.map(\.editedText) == ["greetings", "brave", "world"])
        #expect(timelineRanges.count == 3)
        #expect(abs(timelineRanges[0].lowerBound - 2) < 0.0001)
        #expect(abs(timelineRanges[0].upperBound - 3.3333333333333335) < 0.0001)
        #expect(abs(timelineRanges[1].lowerBound - 3.3333333333333335) < 0.0001)
        #expect(abs(timelineRanges[1].upperBound - 4.666666666666667) < 0.0001)
        #expect(abs(timelineRanges[2].lowerBound - 4.666666666666667) < 0.0001)
        #expect(abs(timelineRanges[2].upperBound - 6) < 0.0001)
    }

}
