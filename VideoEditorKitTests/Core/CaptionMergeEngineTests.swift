import CoreGraphics
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct CaptionMergeEngineTests {

    @Test func replaceAllReturnsOnlyIncomingCaptions() {
        let existing = [
            makeCaption(text: "Old A", startTime: 0, endTime: 2),
            makeCaption(text: "Old B", startTime: 3, endTime: 5)
        ]
        let incoming = [
            makeCaption(text: "New A", startTime: 1, endTime: 4)
        ]

        let result = CaptionMergeEngine.apply(
            incoming: incoming,
            to: existing,
            strategy: .replaceAll
        )

        #expect(result == incoming)
    }

    @Test func appendKeepsExistingCaptionsAndAddsIncomingAtTheEnd() {
        let existing = [
            makeCaption(text: "Old A", startTime: 0, endTime: 2),
            makeCaption(text: "Old B", startTime: 3, endTime: 5)
        ]
        let incoming = [
            makeCaption(text: "New A", startTime: 6, endTime: 8)
        ]

        let result = CaptionMergeEngine.apply(
            incoming: incoming,
            to: existing,
            strategy: .append
        )

        #expect(result.map(\.text) == ["Old A", "Old B", "New A"])
    }

    @Test func replaceIntersectingRemovesOnlyExistingCaptionsThatOverlapIncoming() {
        let existing = [
            makeCaption(text: "Keep A", startTime: 0, endTime: 2),
            makeCaption(text: "Replace B", startTime: 3, endTime: 5),
            makeCaption(text: "Replace C", startTime: 6, endTime: 8),
            makeCaption(text: "Keep D", startTime: 9, endTime: 11)
        ]
        let incoming = [
            makeCaption(text: "New X", startTime: 4, endTime: 7)
        ]

        let result = CaptionMergeEngine.apply(
            incoming: incoming,
            to: existing,
            strategy: .replaceIntersecting
        )

        #expect(result.map(\.text) == ["Keep A", "Keep D", "New X"])
    }

    @Test func replaceIntersectingDoesNotRemoveCaptionThatOnlyTouchesIncomingBoundary() {
        let existing = [
            makeCaption(text: "Keep A", startTime: 0, endTime: 2),
            makeCaption(text: "Keep B", startTime: 5, endTime: 7)
        ]
        let incoming = [
            makeCaption(text: "New X", startTime: 2, endTime: 5)
        ]

        let result = CaptionMergeEngine.apply(
            incoming: incoming,
            to: existing,
            strategy: .replaceIntersecting
        )

        #expect(result.map(\.text) == ["Keep A", "Keep B", "New X"])
    }
}

private extension CaptionMergeEngineTests {
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
