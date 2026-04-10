//
//  HostedVideoEditorRuntimeCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 09.04.2026.
//

import CoreGraphics
import Foundation

@MainActor
enum HostedVideoEditorRuntimeCoordinator {

    // MARK: - Public Methods

    static func bootstrapEditorContent(
        availableSize: CGSize,
        resolvedSourceVideoURL: URL,
        sessionEditingConfiguration: VideoEditingConfiguration?,
        configuration: VideoEditorView.Configuration,
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
            provider: configuration.transcription.provider,
            preferredLocale: configuration.transcription.preferredLocale
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
        currentTimelineTime: Double,
        fallbackEditingConfiguration: VideoEditingConfiguration?
    ) -> VideoEditingConfiguration? {
        editorViewModel.currentEditingConfiguration(
            currentTimelineTime: currentTimelineTime
        ) ?? fallbackEditingConfiguration
    }

    static func scheduleSaveIfNeeded(
        editorViewModel: EditorViewModel,
        currentTimelineTime: Double,
        fallbackSourceVideoURL: URL?,
        saveEmissionCoordinator: VideoEditorSaveEmissionCoordinator,
        onPublish: @escaping @MainActor (VideoEditorSaveEmissionCoordinator.PublishedSave) -> Void
    ) {
        guard
            let currentEditingConfiguration = editorViewModel.currentEditingConfiguration(
                currentTimelineTime: currentTimelineTime
            )
        else {
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

    static func handlePlaybackFocusChange(
        _ isPlaybackFocusActive: Bool,
        editorViewModel: EditorViewModel
    ) {
        guard isPlaybackFocusActive else { return }
        editorViewModel.closeSelectedTool()
    }

    static func handleMaximumVideoDurationChange(
        _ maximumVideoDuration: Double?,
        editorViewModel: EditorViewModel,
        videoPlayer: VideoPlayerManager
    ) {
        editorViewModel.setMaximumVideoDuration(maximumVideoDuration)

        guard let currentVideo = editorViewModel.currentVideo else { return }

        videoPlayer.updatePlaybackRange(
            currentVideo.outputRangeDuration
        )
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
