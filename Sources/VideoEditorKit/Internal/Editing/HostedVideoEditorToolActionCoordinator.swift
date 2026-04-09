#if os(iOS)
    //
    //  HostedVideoEditorToolActionCoordinator.swift
    //  VideoEditorKit
    //
    //  Created by Codex on 09.04.2026.
    //

    import SwiftUI

    @MainActor
    enum HostedVideoEditorToolActionCoordinator {

        private enum Constants {
            static let settleAnimation = Animation.smooth(
                duration: 0.28,
                extraBounce: 0.04
            )
        }

        // MARK: - Public Methods

        static func canApply(
            _ tool: ToolEnum,
            draftState: EditorToolDraftState,
            editorViewModel: EditorViewModel
        ) -> Bool {
            guard let video = editorViewModel.currentVideo else { return false }

            return EditorToolDraftCoordinator.canApply(
                tool,
                video: video,
                draftState: draftState,
                selectedTrack: editorViewModel.presentationState.selectedAudioTrack,
                selectedPreset: editorViewModel.cropPresentationSummary.selectedPreset,
                transcriptState: editorViewModel.transcriptState,
                transcriptDraftDocument: editorViewModel.transcriptDraftDocument,
                transcriptDocument: editorViewModel.transcriptDocument
            )
        }

        static func toolbarItemPresentation(
            for tool: ToolEnum,
            cropPresentationSummary: EditorCropPresentationSummary,
            editorViewModel: EditorViewModel
        ) -> EditorToolbarItemPresentation {
            EditorToolbarItemPresentationResolver.resolve(
                for: tool,
                video: editorViewModel.currentVideo,
                cropPresentationSummary: cropPresentationSummary,
                transcriptDocument: editorViewModel.transcriptDocument
            )
        }

        static func handleToolTap(
            _ toolAvailability: ToolAvailability,
            configuration: VideoEditorView.Configuration,
            editorViewModel: EditorViewModel
        ) {
            guard !toolAvailability.isBlocked else {
                configuration.notifyBlockedToolTap(for: toolAvailability.tool)
                return
            }

            editorViewModel.selectTool(toolAvailability.tool)
        }

        static func loadDraftState(
            for tool: ToolEnum,
            currentState: EditorToolDraftState,
            editorViewModel: EditorViewModel
        ) -> EditorToolDraftState {
            guard let video = editorViewModel.currentVideo else { return currentState }

            let draftState = EditorToolDraftCoordinator.loadedDraftState(
                for: tool,
                currentState: currentState,
                video: video,
                selectedTrack: editorViewModel.presentationState.selectedAudioTrack,
                selectedPreset: editorViewModel.cropPresentationSummary.selectedPreset
            )

            if EditorToolDraftCoordinator.shouldPrepareTranscriptDraft(for: tool) {
                editorViewModel.prepareTranscriptDraftIfNeeded()
            }

            return draftState
        }

        static func reset(
            _ tool: ToolEnum,
            currentDraftState: EditorToolDraftState,
            editorViewModel: EditorViewModel,
            videoPlayer: VideoPlayerManager
        ) -> EditorToolDraftState {
            switch EditorToolDraftCoordinator.resetMode(for: tool) {
            case .animated:
                withAnimation(Constants.settleAnimation) {
                    editorViewModel.reset(
                        tool,
                        videoPlayer: videoPlayer
                    )
                }
            case .transcript:
                editorViewModel.resetTranscript()
            case .standard:
                editorViewModel.reset(
                    tool,
                    videoPlayer: videoPlayer
                )
            }

            let updatedDraftState = loadDraftState(
                for: tool,
                currentState: currentDraftState,
                editorViewModel: editorViewModel
            )
            editorViewModel.closeSelectedTool()

            return updatedDraftState
        }

        static func apply(
            _ tool: ToolEnum,
            draftState: EditorToolDraftState,
            editorViewModel: EditorViewModel,
            videoPlayer: VideoPlayerManager
        ) {
            guard let video = editorViewModel.currentVideo else { return }

            switch tool {
            case .speed:
                applySpeedTool(
                    draftState,
                    editorViewModel: editorViewModel,
                    videoPlayer: videoPlayer
                )
            case .presets:
                applyPresetsTool(
                    draftState,
                    editorViewModel: editorViewModel
                )
            case .audio:
                applyAudioTool(
                    draftState,
                    video: video,
                    editorViewModel: editorViewModel,
                    videoPlayer: videoPlayer
                )
            case .adjusts:
                applyAdjustsTool(
                    draftState,
                    video: video,
                    editorViewModel: editorViewModel,
                    videoPlayer: videoPlayer
                )
            case .transcript:
                applyTranscriptTool(editorViewModel: editorViewModel)
            case .cut:
                break
            }
        }

        // MARK: - Private Methods

        private static func commitAudioVolumeIfNeeded(
            committedValue: Float,
            draftValue: Float,
            track: VideoEditingConfiguration.SelectedTrack,
            editorViewModel: EditorViewModel,
            videoPlayer: VideoPlayerManager
        ) {
            guard abs(Double(committedValue - draftValue)) > 0.001 else { return }

            editorViewModel.selectAudioTrack(track)
            editorViewModel.updateSelectedTrackVolume(
                draftValue,
                videoPlayer: videoPlayer
            )
        }

        private static func applySpeedTool(
            _ draftState: EditorToolDraftState,
            editorViewModel: EditorViewModel,
            videoPlayer: VideoPlayerManager
        ) {
            editorViewModel.handleRateChange(
                Float(draftState.speedDraft),
                videoPlayer: videoPlayer
            )
            editorViewModel.closeSelectedTool()
        }

        private static func applyPresetsTool(
            _ draftState: EditorToolDraftState,
            editorViewModel: EditorViewModel
        ) {
            let selectedPreset = editorViewModel.cropPresentationSummary.selectedPreset

            guard draftState.presetDraft != selectedPreset else {
                editorViewModel.closeSelectedTool()
                return
            }

            withAnimation(Constants.settleAnimation) {
                editorViewModel.selectCropFormat(draftState.presetDraft)
            }
        }

        private static func applyAudioTool(
            _ draftState: EditorToolDraftState,
            video: Video,
            editorViewModel: EditorViewModel,
            videoPlayer: VideoPlayerManager
        ) {
            let committedAudioDraft = AudioToolDraft(
                video: video,
                selectedTrack: editorViewModel.presentationState.selectedAudioTrack
            )

            guard draftState.audioDraft != committedAudioDraft else {
                editorViewModel.closeSelectedTool()
                return
            }

            editorViewModel.selectAudioTrack(draftState.audioDraft.selectedTrack)
            commitAudioVolumeIfNeeded(
                committedValue: video.volume,
                draftValue: draftState.audioDraft.videoVolume,
                track: .video,
                editorViewModel: editorViewModel,
                videoPlayer: videoPlayer
            )

            if video.audio != nil {
                commitAudioVolumeIfNeeded(
                    committedValue: video.audio?.volume ?? 1,
                    draftValue: draftState.audioDraft.recordedVolume,
                    track: .recorded,
                    editorViewModel: editorViewModel,
                    videoPlayer: videoPlayer
                )
            }

            editorViewModel.selectAudioTrack(draftState.audioDraft.selectedTrack)
            editorViewModel.closeSelectedTool()
        }

        private static func applyAdjustsTool(
            _ draftState: EditorToolDraftState,
            video: Video,
            editorViewModel: EditorViewModel,
            videoPlayer: VideoPlayerManager
        ) {
            guard draftState.adjustsDraft != video.colorAdjusts else {
                editorViewModel.closeSelectedTool()
                return
            }

            editorViewModel.setAdjusts(draftState.adjustsDraft)
            videoPlayer.setColorAdjusts(draftState.adjustsDraft)
            editorViewModel.closeSelectedTool()
        }

        private static func applyTranscriptTool(
            editorViewModel: EditorViewModel
        ) {
            editorViewModel.applyTranscriptChanges()
            editorViewModel.closeSelectedTool()
        }

    }

#endif
