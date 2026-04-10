//
//  HostedVideoEditorShellCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 09.04.2026.
//

import Foundation

@MainActor
enum HostedVideoEditorShellCoordinator {

    // MARK: - Public Methods

    static func dismissEditor(
        editorViewModel: EditorViewModel,
        currentTimelineTime: Double,
        fallbackEditingConfiguration: VideoEditingConfiguration?,
        callbacks: VideoEditorView.Callbacks,
        dismiss: () -> Void
    ) {
        callbacks.onDismissed(
            HostedVideoEditorRuntimeCoordinator.dismissedEditingConfiguration(
                editorViewModel: editorViewModel,
                currentTimelineTime: currentTimelineTime,
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
        callbacks: VideoEditorView.Callbacks
    ) {
        videoPlayer.pause()
        callbacks.onExportedVideoURL(video.url)
    }

    static func publishEditingConfigurationIfNeeded(
        editorViewModel: EditorViewModel,
        currentTimelineTime: Double,
        fallbackSourceVideoURL: URL?,
        saveEmissionCoordinator: VideoEditorSaveEmissionCoordinator,
        callbacks: VideoEditorView.Callbacks
    ) {
        HostedVideoEditorRuntimeCoordinator.scheduleSaveIfNeeded(
            editorViewModel: editorViewModel,
            currentTimelineTime: currentTimelineTime,
            fallbackSourceVideoURL: fallbackSourceVideoURL,
            saveEmissionCoordinator: saveEmissionCoordinator
        ) { publishedSave in
            callbacks.onSaveStateChanged(
                .init(
                    editingConfiguration: publishedSave.editingConfiguration,
                    thumbnailData: publishedSave.thumbnailData
                )
            )
        }
    }

}
