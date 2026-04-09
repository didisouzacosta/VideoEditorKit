//
//  HostedVideoEditorExportSheetContentView.swift
//  VideoEditorKit
//
//  Created by Codex on 09.04.2026.
//

import SwiftUI

@MainActor
struct HostedVideoEditorExportSheetContentView: View {

    // MARK: - Public Properties

    let editorViewModel: EditorViewModel
    let videoPlayer: VideoPlayerManager
    let configuration: VideoEditorView.Configuration
    let callbacks: VideoEditorView.Callbacks

    // MARK: - Body

    var body: some View {
        if let video = editorViewModel.currentVideo {
            HostedVideoExporterView(
                video: video,
                editingConfiguration: resolvedEditingConfiguration,
                exportQualities: configuration.exportQualities,
                onBlockedQualityTap: configuration.notifyBlockedExportQualityTap(for:)
            ) { exportedVideo in
                HostedVideoEditorShellCoordinator.handleExportedVideo(
                    exportedVideo,
                    videoPlayer: videoPlayer,
                    callbacks: callbacks
                )
            }
        }
    }

    // MARK: - Private Properties

    private var resolvedEditingConfiguration: VideoEditingConfiguration {
        editorViewModel.exportEditingConfiguration(
            currentTimelineTime: videoPlayer.currentTime
        ) ?? .initial
    }

}
