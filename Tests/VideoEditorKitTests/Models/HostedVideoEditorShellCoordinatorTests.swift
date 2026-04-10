import Foundation
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("HostedVideoEditorShellCoordinatorTests")
struct HostedVideoEditorShellCoordinatorTests {

    // MARK: - Public Methods

    @Test
    func dismissEditorPublishesTheResolvedEditingConfigurationAndCallsDismiss() {
        let editorViewModel = EditorViewModel()
        editorViewModel.currentVideo = Video.mock
        let dismissalRecorder = DismissalRecorder()
        let configurationRecorder = EditingConfigurationRecorder()

        HostedVideoEditorShellCoordinator.dismissEditor(
            editorViewModel: editorViewModel,
            currentTimelineTime: 3,
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
        #expect(dismissalRecorder.count == 1)
    }

    @Test
    func handleExportedVideoPausesPlaybackAndPublishesTheExportURL() {
        let videoPlayer = VideoPlayerManager()
        let exportedURL = URL(fileURLWithPath: "/tmp/exported.mp4")
        var publishedURL: URL?

        HostedVideoEditorShellCoordinator.handleExportedVideo(
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
    func presentExporterPausesPlaybackAndPresentsTheQualitySheet() async throws {
        let editorViewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()

        editorViewModel.currentVideo = Video.mock
        videoPlayer.pause(maintainingPlaybackFocus: true)

        HostedVideoEditorShellCoordinator.presentExporter(
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
    func publishEditingConfigurationIfNeededMapsPublishedSaveIntoThePublicCallbackShape() async throws {
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

        HostedVideoEditorShellCoordinator.publishEditingConfigurationIfNeeded(
            editorViewModel: editorViewModel,
            currentTimelineTime: 2,
            fallbackSourceVideoURL: sourceVideoURL,
            saveEmissionCoordinator: saveEmissionCoordinator,
            callbacks: .init(
                onSaveStateChanged: { saveState in
                    Task {
                        await saveStateRecorder.record(saveState)
                    }
                }
            )
        )

        let saveState = await saveStateRecorder.waitForFirstValue()

        #expect(saveState.editingConfiguration.trim.lowerBound == 0)
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
