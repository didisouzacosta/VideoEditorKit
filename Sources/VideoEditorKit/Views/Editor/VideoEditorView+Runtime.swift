import CoreGraphics
import Foundation

extension VideoEditorView {

    // MARK: - Internal Methods

    static func bootstrapEditorContent(
        availableSize: CGSize,
        resolvedSourceVideoURL: URL,
        sessionEditingConfiguration: VideoEditingConfiguration?,
        configuration: Configuration,
        editorViewModel: EditorViewModel,
        videoPlayer: VideoPlayerManager
    ) {
        editorViewModel.setToolAvailability(configuration.tools)
        handleMaximumVideoDurationChange(
            configuration.maximumVideoDuration,
            editorViewModel: editorViewModel,
            videoPlayer: videoPlayer
        )
        editorViewModel.configureTranscription(
            provider: configuration.transcription?.provider,
            preferredLocale: configuration.transcription?.preferredLocale
        )
        editorViewModel.setSourceVideoIfNeeded(
            resolvedSourceVideoURL,
            editingConfiguration: sessionEditingConfiguration,
            availableSize: availableSize,
            videoPlayer: videoPlayer
        )
    }

    static func resolvedPlayerLoadState(
        for bootstrapState: VideoEditorSessionBootstrapCoordinator.BootstrapState,
        currentVideoURL: URL?
    ) -> LoadState {
        switch bootstrapState {
        case .idle:
            .unknown
        case .loading:
            .loading
        case .loaded(let resolvedSourceVideoURL):
            if currentVideoURL == resolvedSourceVideoURL {
                .loaded(resolvedSourceVideoURL)
            } else {
                .loading
            }
        case .failed:
            .failed
        }
    }

    static func dismissedEditingConfiguration(
        editorViewModel: EditorViewModel,
        fallbackEditingConfiguration: VideoEditingConfiguration?
    ) -> VideoEditingConfiguration? {
        editorViewModel.currentEditingConfiguration() ?? fallbackEditingConfiguration
    }

    static func scheduleSaveIfNeeded(
        editorViewModel: EditorViewModel,
        fallbackSourceVideoURL: URL?,
        saveEmissionCoordinator: VideoEditorSaveEmissionCoordinator,
        onPublish: @escaping @MainActor (VideoEditorSaveEmissionCoordinator.PublishedSave) -> Void
    ) {
        guard let currentEditingConfiguration = editorViewModel.currentEditingConfiguration() else {
            return
        }

        saveEmissionCoordinator.scheduleSave(
            editingConfiguration: currentEditingConfiguration,
            sourceVideoURL: resolvedSourceVideoURL(
                currentVideoURL: editorViewModel.currentVideo?.url,
                fallbackSourceVideoURL: fallbackSourceVideoURL
            ),
            onPublish: onPublish
        )
    }

    static func handleMaximumVideoDurationChange(
        _ maximumVideoDuration: Double?,
        editorViewModel: EditorViewModel,
        videoPlayer: VideoPlayerManager
    ) {
        editorViewModel.setMaximumVideoDuration(maximumVideoDuration)

        guard let currentVideo = editorViewModel.currentVideo else { return }
        videoPlayer.updatePlaybackRange(currentVideo.outputRangeDuration)
    }

    static func dismissEditor(
        editorViewModel: EditorViewModel,
        fallbackEditingConfiguration: VideoEditingConfiguration?,
        callbacks: Callbacks,
        dismiss: () -> Void
    ) {
        callbacks.onDismissed(
            dismissedEditingConfiguration(
                editorViewModel: editorViewModel,
                fallbackEditingConfiguration: fallbackEditingConfiguration
            )
        )
        dismiss()
    }

    static func presentExporter(
        editorViewModel: EditorViewModel,
        videoPlayer: VideoPlayerManager
    ) {
        videoPlayer.pause()
        editorViewModel.presentExporter()
    }

    static func handleRecordedVideo(
        _ url: URL,
        editorViewModel: EditorViewModel,
        videoPlayer: VideoPlayerManager
    ) {
        editorViewModel.handleRecordedVideo(
            url,
            videoPlayer: videoPlayer
        )
    }

    static func handleExportedVideo(
        _ video: ExportedVideo,
        videoPlayer: VideoPlayerManager,
        callbacks: Callbacks
    ) {
        videoPlayer.pause()
        callbacks.onExportedVideoURL(video.url)
    }

    static func handleDisappear(
        saveEmissionCoordinator: VideoEditorSaveEmissionCoordinator,
        editorViewModel: EditorViewModel
    ) {
        saveEmissionCoordinator.reset()
        editorViewModel.cancelDeferredTasks()
    }

    // MARK: - Private Methods

    private static func resolvedSourceVideoURL(
        currentVideoURL: URL?,
        fallbackSourceVideoURL: URL?
    ) -> URL? {
        currentVideoURL ?? fallbackSourceVideoURL
    }

}
