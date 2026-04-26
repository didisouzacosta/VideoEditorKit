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

    static func syncManualSaveState(
        editorViewModel: EditorViewModel,
        manualSaveCoordinator: VideoEditorManualSaveCoordinator
    ) {
        let editingConfiguration = editorViewModel.currentEditingConfiguration()
        manualSaveCoordinator.resetBaselineIfNeeded(to: editingConfiguration)
        manualSaveCoordinator.updateCurrentEditingConfiguration(editingConfiguration)
    }

    static func handleEditingConfigurationChange(
        editorViewModel: EditorViewModel,
        manualSaveCoordinator: VideoEditorManualSaveCoordinator
    ) {
        syncManualSaveState(
            editorViewModel: editorViewModel,
            manualSaveCoordinator: manualSaveCoordinator
        )
    }

    static func performManualSave(
        editorViewModel: EditorViewModel,
        fallbackSourceVideoURL: URL?,
        saveEmissionCoordinator: VideoEditorSaveEmissionCoordinator,
        manualSaveCoordinator: VideoEditorManualSaveCoordinator,
        onPublish: @escaping @MainActor (VideoEditorSaveEmissionCoordinator.PublishedSave) -> Void
    ) {
        guard let currentEditingConfiguration = editorViewModel.currentEditingConfiguration() else {
            return
        }

        guard manualSaveCoordinator.beginSaving() else { return }

        scheduleSaveIfNeeded(
            editorViewModel: editorViewModel,
            fallbackSourceVideoURL: fallbackSourceVideoURL,
            saveEmissionCoordinator: saveEmissionCoordinator,
            onPublish: onPublish
        )
        manualSaveCoordinator.finishSaving(currentEditingConfiguration)
    }

    @discardableResult
    static func performManualSave(
        editorViewModel: EditorViewModel,
        fallbackSourceVideoURL: URL?,
        manualSaveCoordinator: VideoEditorManualSaveCoordinator,
        manualSaveRenderer: VideoEditorManualSaveRenderer = .init(),
        callbacks: Callbacks
    ) async -> SavedVideo? {
        guard
            let video = editorViewModel.currentVideo,
            let currentEditingConfiguration = editorViewModel.currentEditingConfiguration()
        else {
            return nil
        }

        guard manualSaveCoordinator.beginSaving() else { return nil }

        guard
            let originalVideoURL = resolvedSourceVideoURL(
                currentVideoURL: video.url,
                fallbackSourceVideoURL: fallbackSourceVideoURL
            )
        else {
            manualSaveCoordinator.failSaving(
                currentEditingConfiguration: currentEditingConfiguration
            )
            return nil
        }

        do {
            try Task.checkCancellation()

            let savedVideo = try await manualSaveRenderer.save(
                video: video,
                editingConfiguration: currentEditingConfiguration,
                originalVideoURL: originalVideoURL
            )

            try Task.checkCancellation()

            manualSaveCoordinator.finishSaving(currentEditingConfiguration)
            callbacks.onSaveStateChanged(
                .init(
                    editingConfiguration: savedVideo.editingConfiguration,
                    thumbnailData: savedVideo.thumbnailData
                )
            )
            callbacks.onSavedVideo(savedVideo)
            return savedVideo
        } catch {
            manualSaveCoordinator.failSaving(
                currentEditingConfiguration: editorViewModel.currentEditingConfiguration()
            )
            return nil
        }
    }

    static func canPresentManualSaveAction(
        hasLoadedVideo: Bool,
        hasUnsavedChanges: Bool,
        isSaving: Bool = false
    ) -> Bool {
        manualSaveActionPresentation(
            hasLoadedVideo: hasLoadedVideo,
            hasUnsavedChanges: hasUnsavedChanges,
            isSaving: isSaving
        ) == .enabled
    }

    static func manualSaveActionPresentation(
        hasLoadedVideo: Bool,
        hasUnsavedChanges: Bool,
        isSaving: Bool
    ) -> VideoEditorManualSaveActionPresentation {
        guard hasLoadedVideo else { return .hidden }
        guard isSaving == false else { return .loading }
        return hasUnsavedChanges ? .enabled : .disabled
    }

    static func handleCancelRequest(
        hasUnsavedChanges: Bool,
        isSaving: Bool = false,
        cancelSave: () -> Void = {},
        presentConfirmation: (VideoEditorCancelConfirmationState) -> Void,
        dismiss: () -> Void
    ) {
        guard isSaving == false else {
            cancelSave()
            return
        }

        guard hasUnsavedChanges else {
            dismiss()
            return
        }

        presentConfirmation(.unsavedChanges)
    }

    @discardableResult
    static func completeManualSaveInteraction(
        _ savedVideo: SavedVideo?,
        dismiss: () -> Void
    ) -> Bool {
        guard savedVideo != nil else { return false }

        dismiss()
        return true
    }

    static func exportPreparationResult(
        selectedQuality: VideoQuality,
        hasUnsavedChanges: Bool,
        currentEditingConfiguration: VideoEditingConfiguration?,
        lastSavedVideo: SavedVideo?,
        preparedOriginalExportVideo: ExportedVideo?,
        loadedOriginalVideo: ExportedVideo?,
        saveCurrentEdit: () async -> SavedVideo?
    ) async -> ExporterViewModel.ExportPreparationResult {
        if selectedQuality == .original,
            hasUnsavedChanges == false,
            let lastSavedVideo,
            lastSavedVideo.editingConfiguration.continuousSaveFingerprint
                == currentEditingConfiguration?.continuousSaveFingerprint
        {
            return .usePreparedVideo(lastSavedVideo.metadata)
        }

        if selectedQuality == .original,
            hasUnsavedChanges == false,
            let preparedOriginalExportVideo
        {
            return .usePreparedVideo(preparedOriginalExportVideo)
        }

        if selectedQuality == .original,
            hasUnsavedChanges == false,
            currentEditingConfiguration?.continuousSaveFingerprint
                == VideoEditingConfiguration.initial.continuousSaveFingerprint,
            let loadedOriginalVideo
        {
            return .usePreparedVideo(loadedOriginalVideo)
        }

        guard hasUnsavedChanges else { return .render }
        guard let savedVideo = await saveCurrentEdit() else { return .cancelled }

        guard selectedQuality == .original else { return .render }
        return .usePreparedVideo(savedVideo.metadata)
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

    static func prepareExporterPresentation(
        editorViewModel: EditorViewModel,
        fallbackSourceVideoURL: URL?,
        manualSaveCoordinator: VideoEditorManualSaveCoordinator,
        manualSaveRenderer: VideoEditorManualSaveRenderer = .init(),
        videoPlayer: VideoPlayerManager,
        callbacks: Callbacks
    ) async {
        _ = fallbackSourceVideoURL
        _ = manualSaveCoordinator
        _ = manualSaveRenderer
        _ = callbacks

        presentExporter(
            editorViewModel: editorViewModel,
            videoPlayer: videoPlayer
        )
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

    static func handleDisappear(editorViewModel: EditorViewModel) {
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
