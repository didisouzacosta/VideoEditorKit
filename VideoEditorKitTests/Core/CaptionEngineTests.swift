import CoreGraphics
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct CaptionEngineTests {

    @Test func normalizeCaptionsKeepsFullyValidCaption() {
        let caption = makeCaption(
            text: "Hello",
            startTime: 2,
            endTime: 4
        )

        let result = CaptionEngine.normalizeCaptions([caption], to: 0...10)

        #expect(result == [caption])
    }

    @Test func normalizeCaptionsTruncatesCaptionThatPartiallyIntersectsSelectedRange() {
        let caption = makeCaption(
            text: "Hello",
            startTime: 2,
            endTime: 12
        )

        let result = CaptionEngine.normalizeCaptions([caption], to: 5...10)

        #expect(result.count == 1)
        #expect(result[0].startTime == 5)
        #expect(result[0].endTime == 10)
        #expect(result[0].text == "Hello")
    }

    @Test func normalizeCaptionsRemovesCaptionThatEndsBeforeSelectedRange() {
        let caption = makeCaption(
            text: "Hello",
            startTime: 0,
            endTime: 4
        )

        let result = CaptionEngine.normalizeCaptions([caption], to: 5...10)

        #expect(result.isEmpty)
    }

    @Test func normalizeCaptionsRemovesCaptionWithWhitespaceOnlyText() {
        let caption = makeCaption(
            text: "   \n\t  ",
            startTime: 2,
            endTime: 4
        )

        let result = CaptionEngine.normalizeCaptions([caption], to: 0...10)

        #expect(result.isEmpty)
    }

    @Test func normalizeCaptionsRemovesCaptionThatBecomesInvalidAfterClamping() {
        let caption = makeCaption(
            text: "Hello",
            startTime: 10,
            endTime: 10
        )

        let result = CaptionEngine.normalizeCaptions([caption], to: 0...10)

        #expect(result.isEmpty)
    }

    @Test func activeCaptionsReturnsOnlyCaptionsVisibleAtCurrentTimeInsideSelectedRange() {
        let captions = [
            makeCaption(text: "A", startTime: 0, endTime: 3),
            makeCaption(text: "B", startTime: 3, endTime: 6),
            makeCaption(text: "C", startTime: 6, endTime: 9)
        ]

        let result = CaptionEngine.activeCaptions(
            from: captions,
            at: 3,
            in: 0...10
        )

        #expect(result.map(\.text) == ["B"])
    }

    @Test func activeCaptionsReturnsEmptyWhenTimeIsOutsideSelectedRange() {
        let captions = [
            makeCaption(text: "A", startTime: 0, endTime: 3),
            makeCaption(text: "B", startTime: 3, endTime: 6)
        ]

        let result = CaptionEngine.activeCaptions(
            from: captions,
            at: 9,
            in: 0...6
        )

        #expect(result.isEmpty)
    }

    @Test func activeCaptionsIgnoresCaptionTrimmedOutBySelectedRange() {
        let captions = [
            makeCaption(text: "A", startTime: 0, endTime: 2),
            makeCaption(text: "B", startTime: 4, endTime: 8)
        ]

        let result = CaptionEngine.activeCaptions(
            from: captions,
            at: 4.5,
            in: 3...5
        )

        #expect(result.map(\.text) == ["B"])
        #expect(result[0].startTime == 4)
        #expect(result[0].endTime == 5)
    }
}

private extension CaptionEngineTests {
    func makeCaption(
        text: String,
        startTime: Double,
        endTime: Double,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        placementMode: CaptionPlacementMode = .freeform
    ) -> Caption {
        Caption(
            id: UUID(),
            text: text,
            startTime: startTime,
            endTime: endTime,
            position: position,
            placementMode: placementMode,
            style: CaptionStyle(
                fontName: "SFProText-Regular",
                fontSize: 16,
                textColor: .white,
                backgroundColor: .black,
                padding: 12,
                cornerRadius: 8
            )
        )
    }
}
