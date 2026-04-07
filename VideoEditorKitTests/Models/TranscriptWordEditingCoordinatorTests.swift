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
    func reconcileWordsReturnsNilWhenTheEditedSegmentBecomesACompletelyDifferentSentence() {
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

        #expect(reconciledWords == nil)
    }

    @Test
    func reconcileWordsReturnsNilWhenOnlyOneOriginalWordStillMatchesInALongerRewrite() {
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

        #expect(reconciledWords == nil)
    }

}
