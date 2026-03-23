import CoreGraphics
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct CaptionPositionResolverTests {

    @Test func topPresetUsesTopCenterInsetByCaptionBounds() {
        let safeFrame = CGRect(x: 100, y: 200, width: 800, height: 1200)
        let caption = makeCaption(
            text: "Top caption",
            position: .zero,
            placementMode: .preset(.top)
        )

        let point = CaptionPositionResolver.resolve(
            caption: caption,
            renderSize: CGSize(width: 1000, height: 2000),
            safeFrame: safeFrame
        )

        #expect(point.x == 500)
        #expect(point.y > safeFrame.minY)
    }

    @Test func middlePresetUsesCenterOfSafeFrame() {
        let safeFrame = CGRect(x: 100, y: 200, width: 800, height: 1200)

        let point = CaptionPositionResolver.presetPoint(.middle, in: safeFrame)

        #expect(point == CGPoint(x: 500, y: 800))
    }

    @Test func bottomPresetUsesBottomCenterInsetByCaptionBounds() {
        let safeFrame = CGRect(x: 100, y: 200, width: 800, height: 1200)
        let caption = makeCaption(
            text: "Bottom caption",
            position: .zero,
            placementMode: .preset(.bottom)
        )

        let point = CaptionPositionResolver.resolve(
            caption: caption,
            renderSize: CGSize(width: 1000, height: 2000),
            safeFrame: safeFrame
        )

        #expect(point.x == 500)
        #expect(point.y < safeFrame.maxY)
    }

    @Test func freeformPositionInsideSafeFrameRemainsUnchanged() {
        let caption = makeCaption(
            position: CGPoint(x: 0.5, y: 0.5),
            placementMode: .freeform
        )
        let renderSize = CGSize(width: 1000, height: 2000)
        let safeFrame = CGRect(x: 100, y: 200, width: 800, height: 1200)

        let point = CaptionPositionResolver.resolve(
            caption: caption,
            renderSize: renderSize,
            safeFrame: safeFrame
        )

        #expect(point == CGPoint(x: 500, y: 1000))
    }

    @Test func freeformPositionOutsideSafeFrameIsClamped() {
        let caption = makeCaption(
            position: CGPoint(x: 0, y: 1),
            placementMode: .freeform
        )
        let renderSize = CGSize(width: 1000, height: 2000)
        let safeFrame = CGRect(x: 100, y: 200, width: 800, height: 1200)

        let point = CaptionPositionResolver.resolve(
            caption: caption,
            renderSize: renderSize,
            safeFrame: safeFrame
        )

        #expect(point.x > safeFrame.minX)
        #expect(point.y < safeFrame.maxY)

        let frame = CaptionPositionResolver.resolveFrame(
            caption: caption,
            renderSize: renderSize,
            safeFrame: safeFrame
        )

        #expect(frame.minX >= safeFrame.minX)
        #expect(frame.maxX <= safeFrame.maxX)
        #expect(frame.minY >= safeFrame.minY)
        #expect(frame.maxY <= safeFrame.maxY)
    }

    @Test func startingDragConvertsPresetCaptionToFreeformAtResolvedPoint() {
        let caption = makeCaption(
            position: .zero,
            placementMode: .preset(.bottom)
        )
        let renderSize = CGSize(width: 1000, height: 2000)
        let safeFrame = CGRect(x: 100, y: 200, width: 800, height: 1200)

        let convertedCaption = caption.beginningFreeformDrag(
            renderSize: renderSize,
            safeFrame: safeFrame
        )

        #expect(convertedCaption.placementMode == .freeform)
        #expect(abs(convertedCaption.position.x - 0.5) < 0.0001)
        #expect(convertedCaption.position.y < 0.7)
    }
}

private extension CaptionPositionResolverTests {
    func makeCaption(
        text: String = "Caption",
        position: CGPoint,
        placementMode: CaptionPlacementMode
    ) -> Caption {
        Caption(
            id: UUID(),
            text: text,
            startTime: 0,
            endTime: 3,
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
