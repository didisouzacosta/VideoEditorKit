import Foundation
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("VideoEditorViewRuntimeTests", .serialized)
struct VideoEditorViewRuntimeTests {

    // MARK: - Public Methods

    @Test
    func resolvedPlayerLoadStateKeepsBootstrapLoadingUntilTheHostVideoMatches() throws {
        let sourceURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")

        defer { FileManager.default.removeIfExists(for: sourceURL) }

        #expect(
            VideoEditorView.resolvedPlayerLoadState(
                for: .loaded(sourceURL),
                currentVideoURL: nil
            ) == .loading
        )
        #expect(
            VideoEditorView.resolvedPlayerLoadState(
                for: .loaded(sourceURL),
                currentVideoURL: sourceURL
            ) == .loaded(sourceURL)
        )
    }

    @Test
    func dismissedEditingConfigurationFallsBackToTheSessionStateWhenTheEditorHasNoLoadedVideo() {
        let fallbackConfiguration = VideoEditingConfiguration(
            trim: .init(
                lowerBound: 1,
                upperBound: 4
            )
        )
        let editorViewModel = EditorViewModel()

        #expect(
            VideoEditorView.dismissedEditingConfiguration(
                editorViewModel: editorViewModel,
                fallbackEditingConfiguration: fallbackConfiguration
            ) == fallbackConfiguration
        )
    }

    @Test
    func scheduleSaveUsesTheLoadedVideoURLBeforeTheSessionFallbackURL() async throws {
        let currentVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let fallbackSourceVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let sourceURLRecorder = SourceURLRecorder()
        let publishedSaveRecorder = PublishedSaveRecorder()
        let saveEmissionCoordinator = VideoEditorSaveEmissionCoordinator(
            .init(
                sleep: { _ in },
                makeThumbnailData: { sourceVideoURL, _ in
                    await sourceURLRecorder.record(sourceVideoURL)
                    return nil
                }
            )
        )
        let editorViewModel = EditorViewModel()
        var video = Video.mock
        video.url = currentVideoURL
        editorViewModel.currentVideo = video

        VideoEditorView.scheduleSaveIfNeeded(
            editorViewModel: editorViewModel,
            fallbackSourceVideoURL: fallbackSourceVideoURL,
            saveEmissionCoordinator: saveEmissionCoordinator
        ) { publishedSave in
            Task {
                await publishedSaveRecorder.record(publishedSave)
            }
        }

        await publishedSaveRecorder.waitUntilCount(is: 1)

        #expect(await sourceURLRecorder.sourceURLs == [currentVideoURL])
    }

    @Test
    func handleMaximumVideoDurationChangeClampsTheLoadedRangeAndPlayerTime() {
        let editorViewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock
        video.rangeDuration = 0...250
        editorViewModel.currentVideo = video
        videoPlayer.currentTime = 120

        VideoEditorView.handleMaximumVideoDurationChange(
            60,
            editorViewModel: editorViewModel,
            videoPlayer: videoPlayer
        )

        #expect(editorViewModel.currentVideo?.rangeDuration == 0...60)
        #expect(videoPlayer.currentTime == 60)
    }

    @Test
    func dismissEditorPublishesTheResolvedEditingConfigurationAndCallsDismiss() {
        let editorViewModel = EditorViewModel()
        editorViewModel.currentVideo = Video.mock
        let dismissalRecorder = DismissalRecorder()
        let configurationRecorder = EditingConfigurationRecorder()

        VideoEditorView.dismissEditor(
            editorViewModel: editorViewModel,
            fallbackEditingConfiguration: nil,
            callbacks: .init(
                onDismissed: { configuration in
                    configurationRecorder.record(configuration)
                }
            ),
            dismiss: {
                dismissalRecorder.record()
            }
        )

        #expect(configurationRecorder.value != nil)
        #expect(configurationRecorder.value?.playback.currentTimelineTime == nil)
        #expect(dismissalRecorder.count == 1)
    }

    @Test
    func handleExportedVideoPausesPlaybackAndPublishesTheExportURL() {
        let videoPlayer = VideoPlayerManager()
        let exportedURL = URL(fileURLWithPath: "/tmp/exported.mp4")
        var publishedURL: URL?

        VideoEditorView.handleExportedVideo(
            .init(
                exportedURL,
                width: 0,
                height: 0,
                duration: 0,
                fileSize: 0
            ),
            videoPlayer: videoPlayer,
            callbacks: .init(
                onExportedVideoURL: { publishedURL = $0 }
            )
        )

        #expect(videoPlayer.isPlaying == false)
        #expect(publishedURL == exportedURL)
    }

    @Test
    func canPresentManualSaveActionRequiresLoadedVideoAndUnsavedChanges() {
        #expect(
            VideoEditorView.canPresentManualSaveAction(
                hasLoadedVideo: false,
                hasUnsavedChanges: true
            ) == false
        )
        #expect(
            VideoEditorView.canPresentManualSaveAction(
                hasLoadedVideo: true,
                hasUnsavedChanges: false
            ) == false
        )
        #expect(
            VideoEditorView.canPresentManualSaveAction(
                hasLoadedVideo: true,
                hasUnsavedChanges: true
            )
        )
    }

    @Test
    func cancelRequestDismissesImmediatelyWhenThereAreNoUnsavedChanges() {
        let dismissalRecorder = DismissalRecorder()
        var confirmationState: VideoEditorCancelConfirmationState?

        VideoEditorView.handleCancelRequest(
            hasUnsavedChanges: false,
            presentConfirmation: { confirmationState = $0 },
            dismiss: {
                dismissalRecorder.record()
            }
        )

        #expect(confirmationState == nil)
        #expect(dismissalRecorder.count == 1)
    }

    @Test
    func cancelRequestPresentsConfirmationWhenThereAreUnsavedChanges() {
        let dismissalRecorder = DismissalRecorder()
        var confirmationState: VideoEditorCancelConfirmationState?

        VideoEditorView.handleCancelRequest(
            hasUnsavedChanges: true,
            presentConfirmation: { confirmationState = $0 },
            dismiss: {
                dismissalRecorder.record()
            }
        )

        #expect(confirmationState == .unsavedChanges)
        #expect(dismissalRecorder.count == 0)
    }

    @Test
    func syncManualSaveStateStartsCleanForTheFirstLoadedConfiguration() {
        let editorViewModel = EditorViewModel()
        let coordinator = VideoEditorManualSaveCoordinator()
        var video = Video.mock
        video.rangeDuration = 1...8
        editorViewModel.currentVideo = video

        VideoEditorView.syncManualSaveState(
            editorViewModel: editorViewModel,
            manualSaveCoordinator: coordinator
        )

        #expect(coordinator.hasUnsavedChanges == false)
    }

    @Test
    func syncManualSaveStateMarksMeaningfulEditsAsUnsavedAfterBaselineExists() {
        let editorViewModel = EditorViewModel()
        let coordinator = VideoEditorManualSaveCoordinator()
        var video = Video.mock
        video.rangeDuration = 1...8
        editorViewModel.currentVideo = video

        VideoEditorView.syncManualSaveState(
            editorViewModel: editorViewModel,
            manualSaveCoordinator: coordinator
        )

        video.rangeDuration = 2...7
        editorViewModel.currentVideo = video
        VideoEditorView.syncManualSaveState(
            editorViewModel: editorViewModel,
            manualSaveCoordinator: coordinator
        )

        #expect(coordinator.hasUnsavedChanges)
    }

    @Test
    func editingConfigurationChangeTracksUnsavedChangesWithoutPublishingSaveState() {
        let editorViewModel = EditorViewModel()
        let manualSaveCoordinator = VideoEditorManualSaveCoordinator()
        var video = Video.mock
        video.rangeDuration = 1...8
        editorViewModel.currentVideo = video

        VideoEditorView.handleEditingConfigurationChange(
            editorViewModel: editorViewModel,
            manualSaveCoordinator: manualSaveCoordinator
        )

        video.rangeDuration = 2...7
        editorViewModel.currentVideo = video
        VideoEditorView.handleEditingConfigurationChange(
            editorViewModel: editorViewModel,
            manualSaveCoordinator: manualSaveCoordinator
        )

        #expect(manualSaveCoordinator.hasUnsavedChanges)
    }

    @Test
    func performManualSavePublishesSaveStateAndClearsUnsavedChanges() async throws {
        let sourceVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let publishedSaveRecorder = PublishedSaveRecorder()
        let saveEmissionCoordinator = VideoEditorSaveEmissionCoordinator(
            .init(
                sleep: { _ in },
                makeThumbnailData: { _, _ in nil }
            )
        )
        let manualSaveCoordinator = VideoEditorManualSaveCoordinator()
        let editorViewModel = EditorViewModel()
        var video = Video.mock
        video.url = sourceVideoURL
        video.rangeDuration = 1...8
        editorViewModel.currentVideo = video

        VideoEditorView.handleEditingConfigurationChange(
            editorViewModel: editorViewModel,
            manualSaveCoordinator: manualSaveCoordinator
        )

        video.rangeDuration = 2...7
        editorViewModel.currentVideo = video
        VideoEditorView.handleEditingConfigurationChange(
            editorViewModel: editorViewModel,
            manualSaveCoordinator: manualSaveCoordinator
        )
        #expect(manualSaveCoordinator.hasUnsavedChanges)

        VideoEditorView.performManualSave(
            editorViewModel: editorViewModel,
            fallbackSourceVideoURL: sourceVideoURL,
            saveEmissionCoordinator: saveEmissionCoordinator,
            manualSaveCoordinator: manualSaveCoordinator
        ) { publishedSave in
            Task {
                await publishedSaveRecorder.record(publishedSave)
            }
        }

        await publishedSaveRecorder.waitUntilCount(is: 1)

        #expect(manualSaveCoordinator.hasUnsavedChanges == false)
        #expect(await publishedSaveRecorder.saves.first?.editingConfiguration.trim.lowerBound == 2)
    }

    @Test
    func handleDisappearKeepsExplicitManualSaveEmissionAlive() async throws {
        let sourceVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let sleepProbe = ManualSaveSleepProbe()
        let publishedSaveRecorder = PublishedSaveRecorder()
        let saveEmissionCoordinator = VideoEditorSaveEmissionCoordinator(
            .init(
                sleep: { _ in
                    await sleepProbe.sleep()
                },
                makeThumbnailData: { _, _ in nil }
            )
        )
        let manualSaveCoordinator = VideoEditorManualSaveCoordinator()
        let editorViewModel = EditorViewModel()
        var video = Video.mock
        video.url = sourceVideoURL
        editorViewModel.currentVideo = video

        VideoEditorView.performManualSave(
            editorViewModel: editorViewModel,
            fallbackSourceVideoURL: sourceVideoURL,
            saveEmissionCoordinator: saveEmissionCoordinator,
            manualSaveCoordinator: manualSaveCoordinator
        ) { publishedSave in
            Task {
                await publishedSaveRecorder.record(publishedSave)
            }
        }
        await sleepProbe.waitUntilCount(is: 1)

        VideoEditorView.handleDisappear(editorViewModel: editorViewModel)
        await sleepProbe.resumeNext()
        await publishedSaveRecorder.waitUntilCount(is: 1)

        #expect(await publishedSaveRecorder.saves.count == 1)
    }

    @Test
    func presentExporterPausesPlaybackAndPresentsTheQualitySheet() async throws {
        let editorViewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()

        editorViewModel.currentVideo = Video.mock
        videoPlayer.pause(maintainingPlaybackFocus: true)

        VideoEditorView.presentExporter(
            editorViewModel: editorViewModel,
            videoPlayer: videoPlayer
        )

        #expect(videoPlayer.isPlaybackFocusActive == false)

        for _ in 0..<40 where editorViewModel.presentationState.showVideoQualitySheet == false {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(editorViewModel.presentationState.showVideoQualitySheet)
    }

    @Test
    func scheduleSaveCanBeMappedIntoThePublicSaveStateShape() async throws {
        let sourceVideoURL = try TestFixtures.createTemporaryFile(fileExtension: "mp4")
        let saveStateRecorder = SaveStateRecorder()
        let saveEmissionCoordinator = VideoEditorSaveEmissionCoordinator(
            .init(
                sleep: { _ in },
                makeThumbnailData: { _, _ in nil }
            )
        )
        let editorViewModel = EditorViewModel()
        var video = Video.mock
        video.url = sourceVideoURL
        editorViewModel.currentVideo = video

        VideoEditorView.scheduleSaveIfNeeded(
            editorViewModel: editorViewModel,
            fallbackSourceVideoURL: sourceVideoURL,
            saveEmissionCoordinator: saveEmissionCoordinator
        ) { publishedSave in
            Task {
                await saveStateRecorder.record(
                    .init(
                        editingConfiguration: publishedSave.editingConfiguration,
                        thumbnailData: publishedSave.thumbnailData
                    )
                )
            }
        }

        let saveState = await saveStateRecorder.waitForFirstValue()

        #expect(saveState.editingConfiguration.trim.lowerBound == 0)
        #expect(saveState.editingConfiguration.playback.currentTimelineTime == nil)
        #expect(saveState.thumbnailData == nil)
    }

}

@MainActor
private final class DismissalRecorder {

    // MARK: - Private Properties

    private(set) var count = 0

    // MARK: - Public Methods

    func record() {
        count += 1
    }

}

@MainActor
private final class EditingConfigurationRecorder {

    // MARK: - Private Properties

    private(set) var value: VideoEditingConfiguration?

    // MARK: - Public Methods

    func record(_ configuration: VideoEditingConfiguration?) {
        value = configuration
    }

}

private actor SourceURLRecorder {

    // MARK: - Private Properties

    private(set) var sourceURLs = [URL]()

    // MARK: - Public Methods

    func record(_ sourceURL: URL) {
        sourceURLs.append(sourceURL)
    }

}

private actor PublishedSaveRecorder {

    // MARK: - Private Properties

    private(set) var saves = [VideoEditorSaveEmissionCoordinator.PublishedSave]()

    // MARK: - Public Methods

    func record(_ save: VideoEditorSaveEmissionCoordinator.PublishedSave) {
        saves.append(save)
    }

    func waitUntilCount(is expectedCount: Int) async {
        while saves.count < expectedCount {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

}

private actor ManualSaveSleepProbe {

    // MARK: - Private Properties

    private var sleepCount = 0
    private var continuations = [CheckedContinuation<Void, Never>]()

    // MARK: - Public Methods

    func sleep() async {
        sleepCount += 1
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitUntilCount(is expectedCount: Int) async {
        while sleepCount < expectedCount {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func resumeNext() {
        guard continuations.isEmpty == false else { return }
        continuations.removeFirst().resume()
    }

}

private actor SaveStateRecorder {

    // MARK: - Private Properties

    private(set) var values = [VideoEditorView.SaveState]()

    // MARK: - Public Methods

    func record(_ value: VideoEditorView.SaveState) {
        values.append(value)
    }

    func waitForFirstValue() async -> VideoEditorView.SaveState {
        while values.isEmpty {
            try? await Task.sleep(for: .milliseconds(10))
        }

        return values[0]
    }

}
