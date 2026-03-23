import CoreGraphics
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct ProjectValidatorTests {

    @Test func validateProjectReturnsExportableResultForValidProject() {
        let project = makeProject(
            captions: [makeCaption(text: "Hello", startTime: 1, endTime: 3)]
        )

        let result = ProjectValidator.validateProject(
            project: project,
            videoDuration: 10,
            timeRange: makeTimeRangeResult(validRange: 0...10, selectedRange: 0...10)
        )

        #expect(result.canExport)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.isEmpty)
    }

    @Test func validateProjectBlocksExportWhenVideoIsTooShortForPreset() {
        let project = makeProject(
            preset: .instagram,
            selectedTimeRange: 0...2
        )

        let result = ProjectValidator.validateProject(
            project: project,
            videoDuration: 2,
            timeRange: makeTimeRangeResult(
                validRange: 0...2,
                selectedRange: 0...2,
                isVideoTooShort: true
            )
        )

        #expect(result.canExport == false)
        #expect(result.errors == ["Video is too short for preset Instagram."])
    }

    @Test func validateProjectBlocksExportWhenSelectedTimeRangeIsOutOfSync() {
        let project = makeProject(selectedTimeRange: 0...12)

        let result = ProjectValidator.validateProject(
            project: project,
            videoDuration: 12,
            timeRange: makeTimeRangeResult(validRange: 0...10, selectedRange: 0...10)
        )

        #expect(result.canExport == false)
        #expect(result.errors == ["Selected time range is invalid for the current preset."])
    }

    @Test func validateProjectWarnsWhenVideoWillBeTruncatedByPreset() {
        let project = makeProject(
            preset: .youtube,
            selectedTimeRange: 0...60
        )

        let result = ProjectValidator.validateProject(
            project: project,
            videoDuration: 75,
            timeRange: makeTimeRangeResult(
                validRange: 0...60,
                selectedRange: 0...60,
                exceedsMaximum: true
            )
        )

        #expect(result.canExport)
        #expect(result.errors.isEmpty)
        #expect(result.warnings == ["Video duration exceeds the preset maximum and will be truncated."])
    }

    @Test func validateProjectWarnsWhenCaptionsNeedSanitization() {
        let project = makeProject(
            captions: [
                makeCaption(text: "  ", startTime: 1, endTime: 3),
                makeCaption(text: "World", startTime: 1, endTime: 7)
            ],
            selectedTimeRange: 2...6
        )

        let result = ProjectValidator.validateProject(
            project: project,
            videoDuration: 8,
            timeRange: makeTimeRangeResult(validRange: 0...8, selectedRange: 2...6)
        )

        #expect(result.canExport)
        #expect(result.warnings == ["Some captions were sanitized to fit the selected time range."])
    }

    @Test func validateProjectWarnsWhenCaptionFontFallsBackToSystemFont() {
        let project = makeProject(
            captions: [makeCaption(text: "Hello", startTime: 1, endTime: 3, fontName: "DefinitelyMissingFont")]
        )

        let result = ProjectValidator.validateProject(
            project: project,
            videoDuration: 10,
            timeRange: makeTimeRangeResult(validRange: 0...10, selectedRange: 0...10)
        )

        #expect(result.canExport)
        #expect(result.warnings == ["Some caption fonts are unavailable and will fall back to the system font."])
    }
}

private extension ProjectValidatorTests {
    func makeProject(
        sourceVideoURL: URL = URL(fileURLWithPath: "/tmp/video.mov"),
        captions: [Caption] = [],
        preset: ExportPreset = .original,
        gravity: VideoGravity = .fit,
        selectedTimeRange: ClosedRange<Double> = 0...10
    ) -> VideoProject {
        VideoProject(
            sourceVideoURL: sourceVideoURL,
            captions: captions,
            preset: preset,
            gravity: gravity,
            selectedTimeRange: selectedTimeRange
        )
    }

    func makeCaption(
        text: String,
        startTime: Double,
        endTime: Double,
        fontName: String = UIFont.systemFont(ofSize: 16).fontName
    ) -> Caption {
        Caption(
            id: UUID(),
            text: text,
            startTime: startTime,
            endTime: endTime,
            position: CGPoint(x: 0.5, y: 0.5),
            placementMode: .freeform,
            style: CaptionStyle(
                fontName: fontName,
                fontSize: 16,
                textColor: .white,
                backgroundColor: .black,
                padding: 12,
                cornerRadius: 8
            )
        )
    }

    func makeTimeRangeResult(
        validRange: ClosedRange<Double>,
        selectedRange: ClosedRange<Double>,
        isVideoTooShort: Bool = false,
        exceedsMaximum: Bool = false
    ) -> TimeRangeResult {
        TimeRangeResult(
            validRange: validRange,
            selectedRange: selectedRange,
            isVideoTooShort: isVideoTooShort,
            exceedsMaximum: exceedsMaximum
        )
    }
}
