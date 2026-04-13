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
        #expect(viewModel.selectedQuality == .high)
    }

    @Test
    func renderStateTransitionsDriveUiFlagsAndProgressLifecycle() {
        let viewModel = ExporterViewModel(Video.mock)
        let exportedVideo = ExportedVideo(
            URL(fileURLWithPath: "/tmp/exported.mp4"),
            width: 1920,
            height: 1080,
            duration: 12,
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
    func qualitySelectionUpdatesTheCurrentExportQuality() {
        let viewModel = ExporterViewModel(Video.mock)

        viewModel.selectQuality(.medium)

        #expect(viewModel.isSelectedQuality(.medium))
        #expect(viewModel.selectedQuality == .medium)
    }

    @Test
    func blockedPremiumExportDefaultsToLowQuality() {
        let viewModel = ExporterViewModel(
            Video.mock,
            exportQualities: [
                .enabled(.low),
                .blocked(.medium),
                .blocked(.high),
            ]
        )

        #expect(viewModel.selectedQuality == .low)
        #expect(viewModel.canExportVideo)
    }

    @Test
    func blockedQualitySelectionDoesNotOverrideTheCurrentAvailableQuality() {
        let viewModel = ExporterViewModel(
            Video.mock,
            exportQualities: [
                .blocked(.high),
                .enabled(.medium),
                .enabled(.low),
            ]
        )

        #expect(viewModel.selectedQuality == .medium)

        viewModel.selectQuality(.high)

        #expect(viewModel.selectedQuality == .medium)
        #expect(viewModel.isSelectedQuality(.medium))
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
        let expectedVideo = ExportedVideo(
            expectedURL,
            width: 1280,
            height: 720,
            duration: 10,
            fileSize: 1024
        )
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _, onProgress in
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
    func retryExportClearsAlertAndReentersLoadingImmediately() async {
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _, _ in
                _ = await tracker.recordRenderCall()

                do {
                    try await Task.sleep(for: .milliseconds(100))
                    return URL(fileURLWithPath: "/tmp/retry-loading.mp4")
                } catch {
                    throw error
                }
            },
            loadExportedVideo: { url in
                ExportedVideo(
                    url,
                    width: 1280,
                    height: 720,
                    duration: 8,
                    fileSize: 256
                )
            }
        )

        viewModel.renderState = .failed(ExporterError.failed)
        #expect(viewModel.showAlert)

        viewModel.retryExport { _ in }

        #expect(viewModel.showAlert == false)
        #expect(viewModel.renderState == .loading)
        #expect(viewModel.shouldShowLoadingView)

        viewModel.cancelExport()
    }

    @Test
    func repeatedFailuresStillTriggerFailureFeedbackAfterARetry() async {
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _, _ in
                _ = await tracker.recordRenderCall()
                throw ExporterError.failed
            }
        )

        let firstResult = await viewModel.export()

        #expect(firstResult == nil)
        #expect(viewModel.showAlert)
        #expect(viewModel.shouldShowFailureMessage)

        viewModel.retryExport { _ in }

        for _ in 0..<20 where viewModel.renderState == .loading {
            await Task.yield()
        }

        #expect(await tracker.renderCallCount == 2)
        #expect(viewModel.showAlert)
        #expect(viewModel.shouldShowFailureMessage)
        #expect(viewModel.renderState.id == ExporterViewModel.ExportState.failed(ExporterError.failed).id)
    }

    @Test
    func cancelExportResetsTheSheetStateWithoutShowingFailureFeedback() async {
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _, _ in
                _ = await tracker.recordRenderCall()

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

    @Test
    func activeLifecycleStateKeepsAnActiveExportRunning() async {
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _, _ in
                _ = await tracker.recordRenderCall()

                do {
                    try await Task.sleep(for: .seconds(5))
                    return URL(fileURLWithPath: "/tmp/background-short-export.mp4")
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

        viewModel.handleLifecycleStateChange(.active)

        #expect(viewModel.renderState == .loading)
        #expect(viewModel.showAlert == false)
        #expect(await tracker.exportedVideo == nil)

        viewModel.cancelExport()
    }

    @Test
    func inactiveLifecycleStateKeepsAnActiveExportRunning() async {
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _, _ in
                _ = await tracker.recordRenderCall()

                do {
                    try await Task.sleep(for: .seconds(5))
                    return URL(fileURLWithPath: "/tmp/background-expired-export.mp4")
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

        viewModel.handleLifecycleStateChange(.inactive)

        #expect(viewModel.renderState == .loading)
        #expect(viewModel.showAlert == false)
        #expect(await tracker.exportedVideo == nil)

        viewModel.cancelExport()
    }

    @Test
    func shortInactiveInterruptionDoesNotCancelWhenReturningActive() async {
        let tracker = ExportRetryTracker()
        let dateProvider = LifecycleDateProvider(.init(timeIntervalSinceReferenceDate: 0))
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _, _ in
                _ = await tracker.recordRenderCall()

                do {
                    try await Task.sleep(for: .seconds(5))
                    return URL(fileURLWithPath: "/tmp/short-inactive-export.mp4")
                } catch {
                    throw error
                }
            },
            lifecycleNow: dateProvider.currentDate
        )

        viewModel.exportVideo { exportedVideo in
            Task {
                await tracker.recordExportedVideo(exportedVideo)
            }
        }

        for _ in 0..<20 where await tracker.renderCallCount == 0 {
            await Task.yield()
        }

        viewModel.handleLifecycleStateChange(.inactive)
        dateProvider.advance(by: 0.5)
        viewModel.handleLifecycleStateChange(.active)

        #expect(viewModel.renderState == .loading)
        #expect(viewModel.showAlert == false)
        #expect(await tracker.exportedVideo == nil)

        viewModel.cancelExport()
    }

    @Test
    func longInactiveInterruptionCancelsWhenReturningActive() async {
        let tracker = ExportRetryTracker()
        let dateProvider = LifecycleDateProvider(.init(timeIntervalSinceReferenceDate: 0))
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _, _ in
                _ = await tracker.recordRenderCall()

                do {
                    try await Task.sleep(for: .seconds(5))
                    return URL(fileURLWithPath: "/tmp/long-inactive-export.mp4")
                } catch {
                    throw error
                }
            },
            lifecycleNow: dateProvider.currentDate
        )

        viewModel.exportVideo { exportedVideo in
            Task {
                await tracker.recordExportedVideo(exportedVideo)
            }
        }

        for _ in 0..<20 where await tracker.renderCallCount == 0 {
            await Task.yield()
        }

        viewModel.handleLifecycleStateChange(.inactive)
        dateProvider.advance(by: 2)
        viewModel.handleLifecycleStateChange(.active)

        for _ in 0..<20 where viewModel.renderState == .loading {
            await Task.yield()
        }

        #expect(viewModel.shouldShowFailureMessage)
        #expect(viewModel.showAlert)
        #expect(
            viewModel.errorMessage
                == "The export was cancelled because the app moved to the background. Please try again."
        )
        #expect(await tracker.exportedVideo == nil)
    }

    @Test
    func backgroundLifecycleStateCancelsExportWithRecoverableFailure() async {
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _, _ in
                _ = await tracker.recordRenderCall()

                do {
                    try await Task.sleep(for: .seconds(5))
                    return URL(fileURLWithPath: "/tmp/background-cancelled-export.mp4")
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

        viewModel.handleLifecycleStateChange(.background)

        for _ in 0..<20 where viewModel.renderState == .loading {
            await Task.yield()
        }

        #expect(viewModel.shouldShowFailureMessage)
        #expect(viewModel.showAlert)
        #expect(viewModel.canCancelExport == false)
        #expect(
            viewModel.errorMessage
                == "The export was cancelled because the app moved to the background. Please try again."
        )
        #expect(await tracker.exportedVideo == nil)
    }

    @Test
    func retryAfterBackgroundInterruptionStartsANewExport() async {
        let expectedURL = URL(fileURLWithPath: "/tmp/retried-background-export.mp4")
        let expectedVideo = ExportedVideo(
            expectedURL,
            width: 1280,
            height: 720,
            duration: 8,
            fileSize: 256
        )
        let tracker = ExportRetryTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            renderVideo: { _, _, _, _ in
                let renderCallCount = await tracker.recordRenderCall()

                if renderCallCount == 1 {
                    do {
                        try await Task.sleep(for: .seconds(5))
                    } catch {
                        throw error
                    }
                }

                return expectedURL
            },
            loadExportedVideo: { _ in expectedVideo }
        )

        viewModel.exportVideo { exportedVideo in
            Task {
                await tracker.recordExportedVideo(exportedVideo)
            }
        }

        for _ in 0..<20 where await tracker.renderCallCount == 0 {
            await Task.yield()
        }

        viewModel.handleLifecycleStateChange(.background)

        for _ in 0..<20 where viewModel.renderState == .loading {
            await Task.yield()
        }

        #expect(viewModel.shouldShowFailureMessage)

        viewModel.retryExport { exportedVideo in
            Task {
                await tracker.recordExportedVideo(exportedVideo)
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
    func exportPassesEditingConfigurationToRenderer() async {
        let expectedURL = URL(fileURLWithPath: "/tmp/crop-forwarded-export.mp4")
        let editingConfiguration = VideoEditingConfiguration(
            crop: .init(
                rotationDegrees: 0,
                isMirrored: false,
                freeformRect: .init(
                    x: 0.1,
                    y: 0.2,
                    width: 0.6,
                    height: 0.5
                )
            )
        )
        let tracker = ExportConfigurationTracker()
        let viewModel = ExporterViewModel(
            Video.mock,
            editingConfiguration: editingConfiguration,
            renderVideo: { _, configuration, _, _ in
                await tracker.record(configuration)
                return expectedURL
            },
            loadExportedVideo: { url in
                ExportedVideo(
                    url,
                    width: 1280,
                    height: 720,
                    duration: 8,
                    fileSize: 256
                )
            }
        )

        _ = await viewModel.export()

        #expect(await tracker.editingConfiguration == editingConfiguration)
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

private actor ExportConfigurationTracker {

    // MARK: - Private Properties

    private(set) var editingConfiguration: VideoEditingConfiguration?

    // MARK: - Public Methods

    func record(_ configuration: VideoEditingConfiguration) {
        editingConfiguration = configuration
    }

}

private final class LifecycleDateProvider: @unchecked Sendable {

    // MARK: - Private Properties

    private var date: Date

    // MARK: - Initializer

    init(_ date: Date) {
        self.date = date
    }

    // MARK: - Public Methods

    func currentDate() -> Date {
        date
    }

    func advance(by timeInterval: TimeInterval) {
        date = date.addingTimeInterval(timeInterval)
    }

}
