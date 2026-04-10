//
//  VideoEditorToolContentView.swift
//  VideoEditorKit
//
//  Created by Codex on 09.04.2026.
//

import SwiftUI

struct VideoEditorToolContentView: View {

    // MARK: - Bindings

    @Binding private var draftState: EditorToolDraftState

    // MARK: - Public Properties

    let tool: ToolEnum
    let editorViewModel: EditorViewModel

    // MARK: - Body

    var body: some View {
        content
    }

    // MARK: - Private Properties

    @ViewBuilder
    private var content: some View {
        switch tool {
        case .speed:
            VideoSpeedToolView($draftState.speedDraft)
        case .presets:
            PresentToolView(
                selectedPreset: $draftState.presetDraft,
                onSelect: { draftState.presetDraft = $0 }
            )
        case .audio:
            VideoAudioToolView(
                draft: $draftState.audioDraft,
                hasRecordedAudioTrack: editorViewModel.hasRecordedAudioTrack
            )
        case .adjusts:
            VideoAdjustsToolView($draftState.adjustsDraft)
        case .transcript:
            TranscriptToolView(
                isTranscriptionAvailable: editorViewModel.isTranscriptionAvailable,
                transcriptState: editorViewModel.transcriptState,
                document: editorViewModel.transcriptDraftDocument,
                onTranscribe: {
                    editorViewModel.transcribeCurrentVideo()
                },
                onRetry: {
                    editorViewModel.transcribeCurrentVideo()
                },
                onCopyTranscript: { text in
                    PlainTextClipboard.copy(text)
                },
                onUpdateSegmentText: { segmentID, text in
                    editorViewModel.updateTranscriptSegmentText(
                        text,
                        segmentID: segmentID
                    )
                },
                onRevertSegmentText: { segmentID in
                    editorViewModel.revertTranscriptSegmentText(segmentID: segmentID)
                },
                onUpdatePosition: { position in
                    editorViewModel.updateTranscriptOverlayPosition(position)
                },
                onUpdateSize: { size in
                    editorViewModel.updateTranscriptOverlaySize(size)
                }
            )
        case .cut:
            EmptyView()
        }
    }

    // MARK: - Initializer

    init(
        tool: ToolEnum,
        draftState: Binding<EditorToolDraftState>,
        editorViewModel: EditorViewModel
    ) {
        self.tool = tool
        _draftState = draftState

        self.editorViewModel = editorViewModel
    }

}

#Preview {
    @Previewable @State var draftState = EditorToolDraftState()
    NavigationStack {
        VideoEditorToolContentView(
            tool: .speed,
            draftState: $draftState,
            editorViewModel: EditorViewModel()
        )
    }
}
