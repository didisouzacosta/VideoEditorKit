import CoreGraphics
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct VideoEditorControllerEditingTests {

    @Test func selectPresetUsesLoadedDurationToResolveSelectionAndSanitizeCaptions() throws {
        let caption = makeCaption(text: "Hello", startTime: 40, endTime: 120)
        let controller = VideoEditorController(
            project: makeProject(
                captions: [caption],
                preset: .original,
                selectedTimeRange: 40...120
            )
        )

        try controller.loadVideo(duration: 200)
        controller.seek(to: 75)

        controller.selectPreset(.youtube)

        #expect(controller.project.preset == .youtube)
        #expect(controller.project.selectedTimeRange == 40...60)
        #expect(controller.project.captions.count == 1)
        #expect(controller.project.captions[0].startTime == 40)
        #expect(controller.project.captions[0].endTime == 60)
        #expect(controller.playerEngine.currentTime == 60)
    }

    @Test func updateSelectedTimeRangeClampsPlaybackAndClearsTrimmedSelection() throws {
        let keptCaption = makeCaption(text: "Kept", startTime: 1, endTime: 4)
        let removedCaption = makeCaption(text: "Removed", startTime: 7, endTime: 9)
        let controller = VideoEditorController(
            project: makeProject(
                captions: [keptCaption, removedCaption],
                selectedTimeRange: 0...10
            )
        )

        try controller.loadVideo(duration: 10)
        controller.editorState.selectedCaptionID = removedCaption.id
        controller.seek(to: 8)

        controller.updateSelectedTimeRange(0...6)

        #expect(controller.project.selectedTimeRange == 0...6)
        #expect(controller.project.captions.map(\.text) == ["Kept"])
        #expect(controller.editorState.selectedCaptionID == nil)
        #expect(controller.playerEngine.currentTime == 6)
    }

    @Test func selectCaptionStoresExistingIdentifierAndClearsMissingSelection() {
        let caption = makeCaption(text: "Selected", startTime: 0, endTime: 4)
        let controller = VideoEditorController(
            project: makeProject(captions: [caption])
        )

        controller.selectCaption(caption.id)
        #expect(controller.editorState.selectedCaptionID == caption.id)

        controller.selectCaption(UUID())
        #expect(controller.editorState.selectedCaptionID == nil)
    }

    @Test func moveCaptionUpdatesProjectAndConvertsPresetPlacementToFreeform() {
        let caption = makeCaption(
            text: "Preset",
            startTime: 0,
            endTime: 4,
            position: .zero,
            placementMode: .preset(.bottom)
        )
        let controller = VideoEditorController(
            project: makeProject(captions: [caption])
        )

        controller.moveCaption(
            caption.id,
            to: CGPoint(x: 240, y: 490),
            displaySize: CGSize(width: 250, height: 500),
            renderSize: CGSize(width: 1000, height: 2000),
            safeFrame: CGRect(x: 100, y: 200, width: 800, height: 1200)
        )

        #expect(controller.editorState.selectedCaptionID == caption.id)
        #expect(controller.project.captions.count == 1)
        #expect(controller.project.captions[0].placementMode == .freeform)
        #expect(controller.project.captions[0].position.x < 0.9)
        #expect(controller.project.captions[0].position.y < 0.7)

        let frame = CaptionPositionResolver.resolveFrame(
            caption: controller.project.captions[0],
            renderSize: CGSize(width: 1000, height: 2000),
            safeFrame: CGRect(x: 100, y: 200, width: 800, height: 1200)
        )

        #expect(frame.minX >= 100)
        #expect(frame.maxX <= 900)
        #expect(frame.minY >= 200)
        #expect(frame.maxY <= 1400)
    }
}

private extension VideoEditorControllerEditingTests {
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
