#if os(iOS)
    import Foundation
    import Testing

    @testable import VideoEditorKit

    @MainActor
    @Suite("HostedVideoEditorToolActionCoordinatorTests")
    struct HostedVideoEditorToolActionCoordinatorTests {

        // MARK: - Public Methods

        @Test
        func blockedToolTapNotifiesTheHostWithoutChangingSelection() {
            let editorViewModel = EditorViewModel()
            var blockedTool: ToolEnum?

            HostedVideoEditorToolActionCoordinator.handleToolTap(
                .blocked(.adjusts),
                configuration: .init(
                    onBlockedToolTap: { blockedTool = $0 }
                ),
                editorViewModel: editorViewModel
            )

            #expect(blockedTool == .adjusts)
            #expect(editorViewModel.presentationState.selectedTool == nil)
        }

        @Test
        func loadingTranscriptDraftStatePreparesTheDraftDocument() {
            let editorViewModel = EditorViewModel()
            let document = TranscriptDocument(
                segments: [],
                overlayPosition: .bottom,
                overlaySize: .medium
            )
            editorViewModel.currentVideo = Video.mock
            editorViewModel.transcriptDocument = document
            editorViewModel.transcriptDraftDocument = nil

            let draftState = HostedVideoEditorToolActionCoordinator.loadDraftState(
                for: .transcript,
                currentState: .init(),
                editorViewModel: editorViewModel
            )

            #expect(draftState == .init())
            #expect(editorViewModel.transcriptDraftDocument == document)
        }

        @Test
        func applyingAudioDraftCommitsTrackVolumesAndClosesTheSheet() {
            let editorViewModel = EditorViewModel()
            var video = Video.mock
            video.volume = 0.8
            video.audio = Audio(
                url: URL(fileURLWithPath: "/tmp/recorded.m4a"),
                duration: 12,
                volume: 0.35
            )
            editorViewModel.currentVideo = video
            editorViewModel.presentationState.selectedTool = .audio
            editorViewModel.presentationState.selectedAudioTrack = .video

            var draftState = EditorToolDraftState()
            draftState.audioDraft = .init(
                selectedTrack: .recorded,
                videoVolume: 0.55,
                recordedVolume: 0.7
            )

            HostedVideoEditorToolActionCoordinator.apply(
                .audio,
                draftState: draftState,
                editorViewModel: editorViewModel,
                videoPlayer: VideoPlayerManager()
            )

            #expect(editorViewModel.currentVideo?.volume == 0.55)
            #expect(editorViewModel.currentVideo?.audio?.volume == 0.7)
            #expect(editorViewModel.presentationState.selectedAudioTrack == .recorded)
            #expect(editorViewModel.presentationState.selectedTool == nil)
        }

        @Test
        func resettingTranscriptClearsDocumentsAndClosesTheSheet() {
            let editorViewModel = EditorViewModel()
            let document = TranscriptDocument(
                segments: [],
                overlayPosition: .top,
                overlaySize: .large
            )
            editorViewModel.currentVideo = Video.mock
            editorViewModel.presentationState.selectedTool = .transcript
            editorViewModel.transcriptState = .loaded
            editorViewModel.transcriptDocument = document
            editorViewModel.transcriptDraftDocument = document

            let draftState = HostedVideoEditorToolActionCoordinator.reset(
                .transcript,
                currentDraftState: .init(),
                editorViewModel: editorViewModel,
                videoPlayer: VideoPlayerManager()
            )

            #expect(draftState == .init())
            #expect(editorViewModel.transcriptDocument == nil)
            #expect(editorViewModel.transcriptDraftDocument == nil)
            #expect(editorViewModel.presentationState.selectedTool == nil)
        }

    }

#endif
