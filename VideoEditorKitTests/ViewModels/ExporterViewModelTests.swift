import Foundation
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("ExporterViewModelTests")
struct ExporterViewModelTests {

    // MARK: - Public Methods

    @Test
    func initialStateReflectsAnIdleExporter() {
        let viewModel = ExporterViewModel(Video.mock)

        #expect(viewModel.renderState == .unknown)
        #expect(viewModel.isInteractionDisabled == false)
        #expect(viewModel.canExportVideo)
        #expect(viewModel.shouldShowLoadingView == false)
        #expect(viewModel.shouldShowFailureMessage == false)
        #expect(viewModel.showAlert == false)
        #expect(viewModel.selectedQuality == .medium)
    }

    @Test
    func renderStateTransitionsDriveUiFlagsAndTimerLifecycle() {
        let viewModel = ExporterViewModel(Video.mock)

        viewModel.renderState = .loading

        #expect(viewModel.isInteractionDisabled)
        #expect(viewModel.shouldShowLoadingView)
        #expect(viewModel.showAlert == false)

        viewModel.progressTimer = 1.4
        viewModel.renderState = .loaded(URL(fileURLWithPath: "/tmp/exported.mp4"))

        #expect(viewModel.progressTimer == 0)
        #expect(viewModel.shouldShowLoadingView)
        #expect(viewModel.showAlert == false)

        viewModel.progressTimer = 0.8
        viewModel.renderState = .failed(ExporterError.failed)

        #expect(viewModel.progressTimer == 0)
        #expect(viewModel.shouldShowFailureMessage)
        #expect(viewModel.showAlert)
    }

    @Test
    func qualitySelectionAndEstimatedSizeUseTheCurrentVideoDuration() {
        let viewModel = ExporterViewModel(Video.mock)

        viewModel.selectQuality(.high)

        #expect(viewModel.isSelectedQuality(.high))
        #expect(viewModel.selectedQuality == .high)
        #expect(viewModel.estimatedVideoSizeText(for: .medium)?.hasSuffix("Mb") == true)
    }

}
