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
        endTime: Double
    ) -> Caption {
        Caption(
            id: UUID(),
            text: text,
            startTime: startTime,
            endTime: endTime,
            position: CGPoint(x: 0.5, y: 0.5),
            placementMode: .freeform,
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
}
