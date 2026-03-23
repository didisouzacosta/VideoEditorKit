import CoreGraphics
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct VideoEditorTimelineBuilderTests {

    @Test func buildResolvesProgressesCaptionSegmentsAndValidation() {
        let project = makeProject(
            captions: [
                makeCaption(text: "Intro", startTime: 10, endTime: 16),
                makeCaption(text: "Body", startTime: 24, endTime: 38)
            ],
            preset: .youtube,
            selectedTimeRange: 10...40
        )

        let snapshot = VideoEditorTimelineBuilder.build(
            project: project,
            videoDuration: 75,
            currentTime: 25
        )

        #expect(snapshot.validRange == 0...60)
        #expect(snapshot.selectedRange == 10...40)
        #expect(snapshot.currentTime == 25)
        #expect(snapshot.playheadProgress == 25.0 / 60.0)
        #expect(snapshot.selectionStartProgress == 10.0 / 60.0)
        #expect(snapshot.selectionEndProgress == 40.0 / 60.0)
        #expect(snapshot.validation.canExport)
        #expect(snapshot.validation.warnings == ["Video duration exceeds the preset maximum and will be truncated."])
        #expect(snapshot.captions.count == 2)
        #expect(snapshot.captions[0].text == "Intro")
        #expect(snapshot.captions[0].startProgress == 10.0 / 60.0)
        #expect(snapshot.captions[0].endProgress == 16.0 / 60.0)
        #expect(snapshot.captions[1].text == "Body")
        #expect(snapshot.captions[1].startProgress == 24.0 / 60.0)
        #expect(snapshot.captions[1].endProgress == 38.0 / 60.0)
    }

    @Test func buildFlagsTooShortVideoAndClampsPlayheadToSelection() {
        let project = makeProject(
            preset: .instagram,
            selectedTimeRange: 0...2
        )

        let snapshot = VideoEditorTimelineBuilder.build(
            project: project,
            videoDuration: 2,
            currentTime: 7
        )

        #expect(snapshot.validRange == 0...2)
        #expect(snapshot.selectedRange == 0...2)
        #expect(snapshot.currentTime == 2)
        #expect(snapshot.playheadProgress == 1)
        #expect(snapshot.validation.canExport == false)
        #expect(snapshot.validation.errors == ["Video is too short for preset Instagram."])
    }
}

private extension VideoEditorTimelineBuilderTests {
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
