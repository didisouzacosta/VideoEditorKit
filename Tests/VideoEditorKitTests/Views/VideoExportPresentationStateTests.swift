import Testing

@testable import VideoEditorKit

@Suite("VideoExportPresentationStateTests")
struct VideoExportPresentationStateTests {

    @Test
    func idleStateKeepsTheExportButtonInItsDefaultMode() {
        let state = VideoExportPresentationState(
            selectedQuality: .medium,
            exportProgress: 0,
            progressText: "0%",
            errorMessage: "",
            actionTitle: "Export",
            isInteractionDisabled: false,
            canExportVideo: true,
            canCancelExport: false,
            shouldShowLoadingView: false,
            shouldShowFailureMessage: false
        )

        #expect(state.isExporting == false)
        #expect(state.exportButtonTitle == "Export")
        #expect(state.exportButtonProgress == 0)
        #expect(state.shouldShowCancelAction == false)
    }

    @Test
    func loadingStateMovesProgressIntoTheButtonAndShowsCancel() {
        let state = VideoExportPresentationState(
            selectedQuality: .high,
            exportProgress: 0.42,
            progressText: "42%",
            errorMessage: "",
            actionTitle: "Export",
            isInteractionDisabled: true,
            canExportVideo: false,
            canCancelExport: true,
            shouldShowLoadingView: true,
            shouldShowFailureMessage: false
        )

        #expect(state.isExporting)
        #expect(state.exportButtonTitle == "Exporting 42%")
        #expect(state.exportButtonProgress == 0.42)
        #expect(state.shouldShowCancelAction)
    }

    @Test
    func exportButtonProgressIsClampedToTheExpectedRange() {
        let overComplete = VideoExportPresentationState(
            selectedQuality: .low,
            exportProgress: 1.7,
            progressText: "170%",
            errorMessage: "",
            actionTitle: "Export",
            isInteractionDisabled: true,
            canExportVideo: false,
            canCancelExport: true,
            shouldShowLoadingView: true,
            shouldShowFailureMessage: false
        )
        let underComplete = VideoExportPresentationState(
            selectedQuality: .low,
            exportProgress: -0.2,
            progressText: "-20%",
            errorMessage: "",
            actionTitle: "Export",
            isInteractionDisabled: true,
            canExportVideo: false,
            canCancelExport: true,
            shouldShowLoadingView: true,
            shouldShowFailureMessage: false
        )

        #expect(overComplete.exportButtonProgress == 1)
        #expect(underComplete.exportButtonProgress == 0)
    }

}
