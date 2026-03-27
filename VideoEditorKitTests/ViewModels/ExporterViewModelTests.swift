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
        #expect(viewModel.exportProgress == 0)
        #expect(viewModel.progressText == "0%")
        #expect(viewModel.exportActionTitle == "Export")
        #expect(viewModel.selectedQuality == .medium)
    }

    @Test
    func renderStateTransitionsDriveUiFlagsAndProgressLifecycle() {
        let viewModel = ExporterViewModel(Video.mock)

        viewModel.renderState = .loading

        #expect(viewModel.isInteractionDisabled)
        #expect(viewModel.shouldShowLoadingView)
        #expect(viewModel.showAlert == false)
        #expect(viewModel.exportProgress == 0)

        viewModel.exportProgress = 0.48
        viewModel.renderState = .loaded(URL(fileURLWithPath: "/tmp/exported.mp4"))

        #expect(viewModel.exportProgress == 1)
        #expect(viewModel.shouldShowLoadingView == false)
        #expect(viewModel.showAlert == false)

        viewModel.exportProgress = 0.8
        viewModel.renderState = .failed(ExporterError.failed)

        #expect(viewModel.exportProgress == 0)
        #expect(viewModel.shouldShowFailureMessage)
        #expect(viewModel.showAlert)
        #expect(viewModel.exportActionTitle == "Try Again")
        #expect(viewModel.errorMessage == "The video could not be exported. Please try again.")
    }

    @Test
    func qualitySelectionAndEstimatedSizeUseTheCurrentVideoDuration() {
        let viewModel = ExporterViewModel(Video.mock)

        viewModel.selectQuality(.high)

        #expect(viewModel.isSelectedQuality(.high))
        #expect(viewModel.selectedQuality == .high)
        #expect(viewModel.estimatedVideoSizeText(for: .medium)?.hasSuffix("Mb") == true)
    }

    @Test
    func progressTextUsesPercentFormatting() {
        let viewModel = ExporterViewModel(Video.mock)

        viewModel.exportProgress = 0.23

        #expect(viewModel.progressText == "23%")
    }

    @Test
    func failedExportCanBeRetriedWithoutRecreatingTheViewModel() async {
        let expectedURL = URL(fileURLWithPath: "/tmp/retried-export.mp4")
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(Video.mock) { _, _, onProgress in
            let renderCallCount = await tracker.recordRenderCall()
            await onProgress?(0.23)

            if renderCallCount == 1 {
                throw ExporterError.failed
            }

            await onProgress?(1)
            return expectedURL
        }

        let firstResult = await viewModel.export()

        #expect(firstResult == nil)
        #expect(viewModel.shouldShowFailureMessage)
        #expect(viewModel.showAlert)
        #expect(viewModel.exportProgress == 0)

        viewModel.retryExport { url in
            Task {
                await tracker.recordExportedURL(url)
            }
        }

        for _ in 0..<20 where await tracker.exportedURL != expectedURL {
            await Task.yield()
        }

        #expect(await tracker.renderCallCount == 2)
        #expect(await tracker.exportedURL == expectedURL)
        #expect(viewModel.renderState == .loaded(expectedURL))
        #expect(viewModel.exportProgress == 1)
    }

}

private actor ExportRetryTracker {

    // MARK: - Private Properties

    private(set) var renderCallCount = 0
    private(set) var exportedURL: URL?

    // MARK: - Public Methods

    func recordRenderCall() -> Int {
        renderCallCount += 1
        return renderCallCount
    }

    func recordExportedURL(_ url: URL) {
        exportedURL = url
    }

}
