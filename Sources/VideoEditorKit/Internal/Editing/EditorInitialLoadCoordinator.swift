//
//  EditorInitialLoadCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 01.04.2026.
//

import CoreGraphics
import Foundation

struct PreparedEditorInitialLoadState: Equatable, Sendable {

    // MARK: - Public Properties

    let pendingEditingConfiguration: VideoEditingConfiguration?
    let selectedAudioTrack: VideoEditingConfiguration.SelectedTrack
    let selectedTool: ToolEnum?
    let cropEditingState: EditorCropEditingState
    let initialTimelineTime: Double?
    let transcriptFeatureState: TranscriptFeaturePersistenceState
    let transcriptDocument: TranscriptDocument?

}

struct RestoredEditorInitialLoadState: Equatable, Sendable {

    // MARK: - Public Properties

    let cropEditingState: EditorCropEditingState
    let selectedAudioTrack: VideoEditingConfiguration.SelectedTrack
    let selectedTool: ToolEnum?

}

struct EditorInitialLoadCoordinator {

    // MARK: - Public Methods

    static func prepare(
        _ editingConfiguration: VideoEditingConfiguration?
    ) -> PreparedEditorInitialLoadState {
        let transcriptDocument = editingConfiguration?.transcript.document
        let transcriptFeatureState = normalizedTranscriptFeatureState(
            editingConfiguration?.transcript.featureState ?? .idle,
            document: transcriptDocument
        )

        return PreparedEditorInitialLoadState(
            pendingEditingConfiguration: editingConfiguration,
            selectedAudioTrack: .video,
            selectedTool: nil,
            cropEditingState: .initial,
            initialTimelineTime: editingConfiguration?.playback.currentTimelineTime,
            transcriptFeatureState: transcriptFeatureState,
            transcriptDocument: transcriptDocument
        )
    }

    static func applyPendingEditingConfiguration(
        _ editingConfiguration: VideoEditingConfiguration?,
        to video: inout Video,
        containerSize: CGSize,
        resolveLayoutSize: (Video, CGSize) -> CGSize
    ) {
        guard let editingConfiguration else { return }

        VideoEditingConfigurationMapper.apply(editingConfiguration, to: &video)

        let resolvedLayoutSize = resolveLayoutSize(video, containerSize)
        if resolvedLayoutSize.width > 0, resolvedLayoutSize.height > 0 {
            video.frameSize = resolvedLayoutSize
            video.geometrySize = resolvedLayoutSize
        }
    }

    static func restorePendingEditingPresentationState(
        from editingConfiguration: VideoEditingConfiguration?,
        referenceSize: CGSize,
        hasRecordedAudioTrack: Bool,
        enabledTools: Set<ToolEnum>
    ) async -> RestoredEditorInitialLoadState? {
        guard let editingConfiguration else { return nil }

        let resolvedState = await VideoEditingPresentationStateResolver.resolve(
            from: editingConfiguration,
            referenceSize: referenceSize,
            hasRecordedAudioTrack: hasRecordedAudioTrack,
            enabledTools: enabledTools
        )

        return RestoredEditorInitialLoadState(
            cropEditingState: .init(
                freeformRect: resolvedState.cropFreeformRect,
                socialVideoDestination: resolvedState.socialVideoDestination,
                showsSafeAreaOverlay: resolvedState.showsSafeAreaOverlay,
                canvasSnapshot: resolvedState.canvasSnapshot
            ),
            selectedAudioTrack: resolvedState.selectedAudioTrack,
            selectedTool: resolvedState.selectedTool
        )
    }

    // MARK: - Private Methods

    private static func normalizedTranscriptFeatureState(
        _ featureState: TranscriptFeaturePersistenceState,
        document: TranscriptDocument?
    ) -> TranscriptFeaturePersistenceState {
        guard document != nil else {
            return .idle
        }

        return .loaded
    }

}
