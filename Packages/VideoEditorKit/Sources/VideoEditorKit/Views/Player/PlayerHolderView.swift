//
//  PlayerHolderView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@MainActor
struct PlayerHolderView: View {

    private enum Constants {
        static let settleAnimation = Animation.smooth(
            duration: 0.28,
            extraBounce: 0.04
        )
    }

    // MARK: - Private Properties

    private let editorViewModel: EditorViewModel
    private let videoPlayer: VideoPlayerManager

    // MARK: - Body

    var body: some View {
        VideoEditorPlayerStageView(
            presentationState,
            canvasEditorState: canvasEditorState,
            source: canvasSource,
            isCanvasInteractive: cropPresentationSummary.isCropOverlayInteractive,
            layoutTaskID: playerLayoutID,
            onInteractionStarted: {
                videoPlayer.beginPlaybackInteraction()
            },
            onInteractionEnded: { _ in
                videoPlayer.endPlaybackInteraction()
            },
            onSnapshotChange: { _ in
                editorViewModel.handleCanvasPreviewChange()
            },
            onLayoutResolved: syncVideoLayout
        ) {
            playerContent
        } overlay: { canvasLayout in
            transcriptOverlay(
                canvasLayout: canvasLayout
            )
        } trailingControls: {
            trailingPlayerControls(cropPresentationSummary)
        }
    }

    // MARK: - Initializer

    init(
        _ editorViewModel: EditorViewModel,
        videoPlayer: VideoPlayerManager
    ) {
        self.editorViewModel = editorViewModel
        self.videoPlayer = videoPlayer
    }

}

extension PlayerHolderView {

    // MARK: - Private Properties

    private var presentationState: VideoEditorPlayerStageState {
        HostedVideoEditorPlayerStageCoordinator.presentationState(
            for: videoPlayer.loadState
        )
    }

    private var canvasEditorState: VideoCanvasEditorState? {
        HostedVideoEditorPlayerStageCoordinator.canvasEditorState(
            editorViewModel: editorViewModel
        )
    }

    private var canvasSource: VideoCanvasSourceDescriptor? {
        HostedVideoEditorPlayerStageCoordinator.canvasSource(
            editorViewModel: editorViewModel
        )
    }

    private var cropPresentationSummary: EditorCropPresentationSummary {
        HostedVideoEditorPlayerStageCoordinator.cropPresentationSummary(
            editorViewModel: editorViewModel,
            isPlaybackFocused: videoPlayer.isPlaybackFocusActive
        )
    }

    private var transcriptOverlayContext: HostedVideoEditorPlayerStageCoordinator.TranscriptOverlayContext? {
        HostedVideoEditorPlayerStageCoordinator.transcriptOverlayContext(
            editorViewModel: editorViewModel,
            currentTimelineTime: videoPlayer.currentTime
        )
    }

    private var playerContent: some View {
        VideoEditorPlayerSurfaceView(
            backgroundColor: editorViewModel.frames.frameColor,
            scale: editorViewModel.frames.scale,
            animation: Constants.settleAnimation
        ) {
            PlayerView(videoPlayer.videoPlayer)
                .allFrame()
        }
    }

    private var playerLayoutID: String? {
        HostedVideoEditorPlayerStageCoordinator.playerLayoutID(
            editorViewModel: editorViewModel
        )
    }

    private func trailingPlayerControls(
        _ cropSummary: EditorCropPresentationSummary
    ) -> some View {
        HostedVideoEditorPlayerTrailingControlsView(
            shouldShowResetButton: cropSummary.shouldShowCanvasResetButton,
            onReset: {
                editorViewModel.resetCanvasTransform()
            }
        )
    }

    private func transcriptOverlay(
        canvasLayout: VideoCanvasLayout
    ) -> some View {
        HostedVideoEditorPlayerOverlayView(
            context: transcriptOverlayContext,
            canvasLayout: canvasLayout
        )
    }

    // MARK: - Private Methods

    private func syncVideoLayout(_ canvasLayout: VideoCanvasLayout) {
        HostedVideoEditorPlayerStageCoordinator.syncVideoLayout(
            canvasLayout,
            editorViewModel: editorViewModel
        )
    }

}
#Preview {
    HostedVideoEditorView()
}
