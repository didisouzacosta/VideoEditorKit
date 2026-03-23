import CoreGraphics
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct VideoEditorPreviewBuilderTests {

    @Test func buildResolvesSafeFrameAndKeepsBottomPresetInsideSafeFrame() {
        let caption = makeCaption(
            text: "Bottom",
            startTime: 0,
            endTime: 10,
            position: .zero,
            placementMode: .preset(.bottom)
        )

        let snapshot = VideoEditorPreviewBuilder.build(
            project: makeProject(captions: [caption], preset: .instagram),
            currentTime: 4,
            videoSize: CGSize(width: 1920, height: 1080),
            containerSize: CGSize(width: 270, height: 480)
        )

        #expect(snapshot.layout.renderSize == CGSize(width: 1080, height: 1920))
        assertRect(
            snapshot.safeFrame,
            approximatelyEquals: CGRect(x: 32, y: 120, width: 1016, height: 1540)
        )
        #expect(snapshot.captions.count == 1)
        #expect(abs(snapshot.captions[0].center.x - 540) <= 0.0001)
        #expect(snapshot.captions[0].center.y < snapshot.safeFrame.maxY)
    }

    @Test func buildFiltersInactiveCaptionsAndClampsFreeformCaptionToSafeFrame() {
        let activeCaption = makeCaption(
            text: "Active",
            startTime: 2,
            endTime: 8,
            position: CGPoint(x: 1, y: 1),
            placementMode: .freeform
        )
        let inactiveCaption = makeCaption(
            text: "Inactive",
            startTime: 8,
            endTime: 10,
            position: CGPoint(x: 0.5, y: 0.5),
            placementMode: .freeform
        )

        let snapshot = VideoEditorPreviewBuilder.build(
            project: makeProject(
                captions: [activeCaption, inactiveCaption],
                preset: .original,
                selectedTimeRange: 2...6
            ),
            currentTime: 5,
            videoSize: CGSize(width: 1920, height: 1080),
            containerSize: CGSize(width: 320, height: 180)
        )

        #expect(snapshot.captions.map(\.text) == ["Active"])
        let expectedCenter = CaptionPositionResolver.resolve(
            caption: activeCaption,
            renderSize: snapshot.layout.renderSize,
            safeFrame: snapshot.safeFrame
        )
        assertPoint(
            snapshot.captions[0].center,
            approximatelyEquals: expectedCenter
        )
    }
}

private extension VideoEditorPreviewBuilderTests {
    func makeProject(
        captions: [Caption] = [],
        preset: ExportPreset = .original,
        selectedTimeRange: ClosedRange<Double> = 0...10
    ) -> VideoProject {
        VideoProject(
            sourceVideoURL: URL(fileURLWithPath: "/tmp/video.mov"),
            captions: captions,
            preset: preset,
            gravity: .fit,
            selectedTimeRange: selectedTimeRange
        )
    }

    func makeCaption(
        text: String,
        startTime: Double,
        endTime: Double,
        position: CGPoint,
        placementMode: CaptionPlacementMode
    ) -> Caption {
        Caption(
            id: UUID(),
            text: text,
            startTime: startTime,
            endTime: endTime,
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

    func assertRect(
        _ actual: CGRect,
        approximatelyEquals expected: CGRect,
        tolerance: CGFloat = 0.0001
    ) {
        #expect(abs(actual.origin.x - expected.origin.x) <= tolerance)
        #expect(abs(actual.origin.y - expected.origin.y) <= tolerance)
        #expect(abs(actual.size.width - expected.size.width) <= tolerance)
        #expect(abs(actual.size.height - expected.size.height) <= tolerance)
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
