//
//  HostedVideoEditorLoadedContentView.swift
//  VideoEditorKit
//
//  Created by Codex on 09.04.2026.
//

import SwiftUI

@MainActor
struct HostedVideoEditorLoadedContentView: View {

    // MARK: - Public Properties

    let availableSize: CGSize
    let resolvedSourceVideoURL: URL
    let sessionEditingConfiguration: VideoEditingConfiguration?
    let configuration: VideoEditorView.Configuration
    let editorViewModel: EditorViewModel
    let videoPlayer: VideoPlayerManager

    // MARK: - Body

    var body: some View {
        VideoEditorLoadedView(
            availableSize: availableSize,
            resolvedSourceVideoURL: resolvedSourceVideoURL,
            isPlaybackFocused: videoPlayer.isPlaybackFocusActive,
            onLoad: bootstrapEditorContent
        ) {
            PlayerHolderView(
                editorViewModel,
                videoPlayer: videoPlayer
            )
        } controlsContent: {
            HostedVideoEditorTrimSectionView(
                editorViewModel,
                videoPlayer: videoPlayer
            )
        } toolsContent: {
            ToolsSectionView(
                videoPlayer,
                editorVM: editorViewModel,
                configuration: configuration
            )
        }
    }

    // MARK: - Private Methods

    private func bootstrapEditorContent(
        for availableSize: CGSize,
        resolvedSourceVideoURL: URL
    ) {
        HostedVideoEditorRuntimeCoordinator.bootstrapEditorContent(
            availableSize: availableSize,
            resolvedSourceVideoURL: resolvedSourceVideoURL,
            sessionEditingConfiguration: sessionEditingConfiguration,
            configuration: configuration,
            editorViewModel: editorViewModel,
            videoPlayer: videoPlayer
        )
    }

}

#Preview {
    HostedVideoEditorLoadedContentView(
        availableSize: CGSize(width: 390, height: 700),
        resolvedSourceVideoURL: URL(filePath: "/dev/null"),
        sessionEditingConfiguration: nil,
        configuration: .init(),
        editorViewModel: EditorViewModel(),
        videoPlayer: VideoPlayerManager()
    )
}
