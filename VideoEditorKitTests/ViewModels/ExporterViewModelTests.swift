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
        let exportedVideo = ExportedVideo(
            URL(fileURLWithPath: "/tmp/exported.mp4"),
            width: 1920,
            height: 1080,
            fileSize: 512
        )

        viewModel.renderState = .loading

        #expect(viewModel.isInteractionDisabled)
        #expect(viewModel.canCancelExport)
        #expect(viewModel.shouldShowLoadingView)
        #expect(viewModel.showAlert == false)
        #expect(viewModel.exportProgress == 0)

        viewModel.exportProgress = 0.48
        viewModel.renderState = .loaded(exportedVideo)

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
        let expectedVideo = ExportedVideo(expectedURL, width: 1280, height: 720, fileSize: 1024)
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, onProgress in
                let renderCallCount = await tracker.recordRenderCall()
                await onProgress?(0.23)

                if renderCallCount == 1 {
                    throw ExporterError.failed
                }

                await onProgress?(1)
                return expectedURL
            },
            loadExportedVideo: { _ in expectedVideo }
        )

        let firstResult = await viewModel.export()

        #expect(firstResult == nil)
        #expect(viewModel.shouldShowFailureMessage)
        #expect(viewModel.showAlert)
        #expect(viewModel.exportProgress == 0)

        viewModel.retryExport { url in
            Task {
                await tracker.recordExportedVideo(url)
            }
        }

        for _ in 0..<20 where await tracker.exportedVideo != expectedVideo {
            await Task.yield()
        }

        #expect(await tracker.renderCallCount == 2)
        #expect(await tracker.exportedVideo == expectedVideo)
        #expect(viewModel.renderState == .loaded(expectedVideo))
        #expect(viewModel.exportProgress == 1)
    }

    @Test
    func cancelExportResetsTheSheetStateWithoutShowingFailureFeedback() async {
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _ in
                await tracker.recordRenderCall()

                do {
                    try await Task.sleep(for: .seconds(5))
                    return URL(fileURLWithPath: "/tmp/should-not-complete.mp4")
                } catch {
                    throw error
                }
            }
        )

        viewModel.exportVideo { exportedVideo in
            Task {
                await tracker.recordExportedVideo(exportedVideo)
            }
        }

        for _ in 0..<20 where await tracker.renderCallCount == 0 {
            await Task.yield()
        }

        #expect(viewModel.renderState == .loading)

        viewModel.cancelExport()

        for _ in 0..<20 where viewModel.renderState != .unknown {
            await Task.yield()
        }

        #expect(viewModel.renderState == .unknown)
        #expect(viewModel.showAlert == false)
        #expect(viewModel.exportProgress == 0)
        #expect(viewModel.canCancelExport == false)
        #expect(await tracker.exportedVideo == nil)
    }

}

private actor ExportRetryTracker {

    // MARK: - Private Properties

    private(set) var renderCallCount = 0
    private(set) var exportedVideo: ExportedVideo?

    // MARK: - Public Methods

    func recordRenderCall() -> Int {
        renderCallCount += 1
        return renderCallCount
    }

    func recordExportedVideo(_ video: ExportedVideo) {
        exportedVideo = video
    }

}
