import CoreGraphics
import Testing
import UIKit
@testable import VideoEditorKit

@MainActor
struct VideoEditorControllerCaptionActionTests {

    @Test func performCaptionActionReplaceAllSanitizesIncomingCaptionsAndClearsSelection() async throws {
        let existingCaption = makeCaption(text: "Existing", startTime: 2, endTime: 4)
        let replacementCaption = makeCaption(text: "Replacement", startTime: 1, endTime: 7)
        let emptyCaption = makeCaption(text: "   ", startTime: 2, endTime: 3)

        let controller = VideoEditorController(
            project: makeProject(captions: [existingCaption], selectedTimeRange: 2...6),
            config: VideoEditorConfig(
                onCaptionAction: { _, _ in [emptyCaption, replacementCaption] },
                captionApplyStrategy: .replaceAll
            )
        )
        controller.editorState.selectedCaptionID = existingCaption.id

        try await controller.performCaptionAction(.generate, videoDuration: 8)

        #expect(controller.editorState.captionState == .idle)
        #expect(controller.editorState.selectedCaptionID == nil)
        #expect(controller.project.captions.map(\.text) == ["Replacement"])
        #expect(controller.project.captions[0].startTime == 2)
        #expect(controller.project.captions[0].endTime == 6)
    }

    @Test func performCaptionActionAppendNormalizesExistingAndIncomingCaptions() async throws {
        let existingCaption = makeCaption(text: "Existing", startTime: 0, endTime: 4)
        let incomingCaption = makeCaption(text: "Incoming", startTime: 5, endTime: 8)

        let controller = VideoEditorController(
            project: makeProject(captions: [existingCaption], selectedTimeRange: 2...6),
            config: VideoEditorConfig(
                onCaptionAction: { _, _ in [incomingCaption] },
                captionApplyStrategy: .append
            )
        )

        try await controller.performCaptionAction(.generate, videoDuration: 8)

        #expect(controller.project.captions.map(\.text) == ["Existing", "Incoming"])
        #expect(controller.project.captions[0].startTime == 2)
        #expect(controller.project.captions[0].endTime == 4)
        #expect(controller.project.captions[1].startTime == 5)
        #expect(controller.project.captions[1].endTime == 6)
    }

    @Test func performCaptionActionReplaceIntersectingPreservesOnlyNonOverlappingExistingCaptions() async throws {
        let preservedCaption = makeCaption(text: "Preserved", startTime: 0, endTime: 2)
        let removedCaption = makeCaption(text: "Removed", startTime: 3, endTime: 5)
        let incomingCaption = makeCaption(text: "Incoming", startTime: 4, endTime: 6)

        let controller = VideoEditorController(
            project: makeProject(captions: [preservedCaption, removedCaption], selectedTimeRange: 0...10),
            config: VideoEditorConfig(
                onCaptionAction: { _, _ in [incomingCaption] },
                captionApplyStrategy: .replaceIntersecting
            )
        )

        try await controller.performCaptionAction(.translate, videoDuration: 10)

        #expect(controller.project.captions.map(\.text) == ["Preserved", "Incoming"])
    }

    @Test func performCaptionActionFailsWhenProviderIsUnavailable() async {
        let controller = VideoEditorController(project: makeProject(), config: VideoEditorConfig())

        do {
            try await controller.performCaptionAction(.generate, videoDuration: 10)
            Issue.record("Expected captionProviderUnavailable.")
        } catch let error as VideoEditorError {
            #expect(error == .captionProviderUnavailable)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(controller.editorState.captionState == .failed(message: "Caption provider is unavailable."))
    }

    @Test func performCaptionActionFailsWhenAnotherCaptionRequestIsAlreadyRunning() async {
        let controller = VideoEditorController(project: makeProject(), config: VideoEditorConfig())
        controller.editorState.captionState = .loading

        do {
            try await controller.performCaptionAction(.generate, videoDuration: 10)
            Issue.record("Expected captionGenerationInProgress.")
        } catch let error as VideoEditorError {
            #expect(error == .captionGenerationInProgress)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func performCaptionActionMapsProviderFailureToPublicErrorAndState() async {
        struct ProviderFailure: LocalizedError {
            var errorDescription: String? { "Provider offline" }
        }

        let controller = VideoEditorController(
            project: makeProject(),
            config: VideoEditorConfig(
                onCaptionAction: { _, _ in throw ProviderFailure() }
            )
        )

        do {
            try await controller.performCaptionAction(.generate, videoDuration: 10)
            Issue.record("Expected captionProviderFailed.")
        } catch let error as VideoEditorError {
            #expect(error == .captionProviderFailed(reason: "Provider offline"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(controller.editorState.captionState == .failed(message: "Provider offline"))
    }
}

private extension VideoEditorControllerCaptionActionTests {
    func makeProject(
        captions: [Caption] = [],
        selectedTimeRange: ClosedRange<Double> = 0...10
    ) -> VideoProject {
        VideoProject(
            sourceVideoURL: URL(fileURLWithPath: "/tmp/video.mov"),
            captions: captions,
            preset: .original,
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
