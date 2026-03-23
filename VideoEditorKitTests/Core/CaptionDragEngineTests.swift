import CoreGraphics
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct CaptionDragEngineTests {

    @Test func repositionConvertsPreviewPointToNormalizedRenderCoordinates() {
        let caption = makeCaption(
            position: CGPoint(x: 0.5, y: 0.5),
            placementMode: .freeform
        )

        let repositioned = CaptionDragEngine.reposition(
            caption,
            to: CGPoint(x: 75, y: 100),
            displaySize: CGSize(width: 250, height: 500),
            renderSize: CGSize(width: 1000, height: 2000),
            safeFrame: CGRect(x: 100, y: 200, width: 800, height: 1200)
        )

        #expect(repositioned.placementMode == .freeform)
        assertPoint(
            repositioned.position,
            approximatelyEquals: CGPoint(x: 0.3, y: 0.2)
        )
    }

    @Test func repositionClampsDraggedCaptionToSafeFrameAndConvertsPresetToFreeform() {
        let caption = makeCaption(
            position: .zero,
            placementMode: .preset(.bottom)
        )

        let repositioned = CaptionDragEngine.reposition(
            caption,
            to: CGPoint(x: 240, y: 490),
            displaySize: CGSize(width: 250, height: 500),
            renderSize: CGSize(width: 1000, height: 2000),
            safeFrame: CGRect(x: 100, y: 200, width: 800, height: 1200)
        )

        #expect(repositioned.placementMode == .freeform)
        #expect(repositioned.position.x < 0.9)
        #expect(repositioned.position.y < 0.7)

        let frame = CaptionPositionResolver.resolveFrame(
            caption: repositioned,
            renderSize: CGSize(width: 1000, height: 2000),
            safeFrame: CGRect(x: 100, y: 200, width: 800, height: 1200)
        )

        #expect(frame.minX >= 100)
        #expect(frame.maxX <= 900)
        #expect(frame.minY >= 200)
        #expect(frame.maxY <= 1400)
    }
}

private extension CaptionDragEngineTests {
    func makeCaption(
        position: CGPoint,
        placementMode: CaptionPlacementMode
    ) -> Caption {
        Caption(
            id: UUID(),
            text: "Caption",
            startTime: 0,
            endTime: 3,
            position: position,
            placementMode: placementMode,
            style: CaptionStyle(
                fontName: UIFont.systemFont(ofSize: 16).fontName,
                fontSize: 16,
                textColor: .white,
                backgroundColor: .black,
                padding: 12,
                cornerRadius: 8
            )
        )
    }

    func assertPoint(
        _ actual: CGPoint,
        approximatelyEquals expected: CGPoint,
        tolerance: CGFloat = 0.0001
    ) {
        #expect(abs(actual.x - expected.x) <= tolerance)
        #expect(abs(actual.y - expected.y) <= tolerance)
    }
}
