import CoreGraphics
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct CaptionPositionResolverTests {

    @Test func topPresetUsesTopCenterOfSafeFrame() {
        let safeFrame = CGRect(x: 100, y: 200, width: 800, height: 1200)

        let point = CaptionPositionResolver.presetPoint(.top, in: safeFrame)

        #expect(point == CGPoint(x: 500, y: 200))
    }

    @Test func middlePresetUsesCenterOfSafeFrame() {
        let safeFrame = CGRect(x: 100, y: 200, width: 800, height: 1200)

        let point = CaptionPositionResolver.presetPoint(.middle, in: safeFrame)

        #expect(point == CGPoint(x: 500, y: 800))
    }

    @Test func bottomPresetUsesBottomCenterOfSafeFrame() {
        let safeFrame = CGRect(x: 100, y: 200, width: 800, height: 1200)

        let point = CaptionPositionResolver.presetPoint(.bottom, in: safeFrame)

        #expect(point == CGPoint(x: 500, y: 1400))
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

        #expect(point == CGPoint(x: 100, y: 1400))
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
        #expect(abs(convertedCaption.position.y - 0.7) < 0.0001)
    }
}

private extension CaptionPositionResolverTests {
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
