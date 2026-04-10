import SwiftUI

struct ToolsSectionView: View {

    // MARK: - States

    @State private var draftState = EditorToolDraftState()

    // MARK: - Private Properties

    private let videoPlayer: VideoPlayerManager
    private let editorViewModel: EditorViewModel
    private let configuration: VideoEditorView.Configuration

    // MARK: - Body

    var body: some View {
        let currentVideo = editorViewModel.currentVideo
        let cropPresentationSummary = editorViewModel.cropPresentationSummary
        let transcriptDocument = editorViewModel.transcriptDocument

        VideoEditorToolsTrayView(
            selectedTool: selectedToolBinding,
            initialSheetHeight: VideoEditorToolSheetPresentationPolicy.initialSheetHeight(for:)
        ) {
            PagedToolsRow(configuration.tools) { tool in
                toolbarItemPresentation(
                    for: tool,
                    currentVideo: currentVideo,
                    cropPresentationSummary: cropPresentationSummary,
                    transcriptDocument: transcriptDocument
                )
            } action: { toolAvailability in
                handleToolTap(toolAvailability)
            }
        } sheetContent: { tool in
            toolSheet(tool)
        }
        .onChange(of: editorViewModel.currentVideo) { _, newValue in
            if newValue == nil {
                selectedToolBinding.wrappedValue = nil
            }
            editorViewModel.handleCurrentVideoChange(
                newValue,
                videoPlayer: videoPlayer
            )
        }
    }

    // MARK: - Initializer

    init(
        _ videoPlayer: VideoPlayerManager,
        editorVM: EditorViewModel,
        configuration: VideoEditorView.Configuration
    ) {
        self.videoPlayer = videoPlayer
        self.editorViewModel = editorVM
        self.configuration = configuration
    }

}

extension ToolsSectionView {

    private func toolSheet(_ tool: ToolEnum) -> some View {
        VideoEditorToolSheetView(
            title: tool.title,
            contentInteraction: VideoEditorToolSheetPresentationPolicy.contentInteraction(for: tool),
            onClose: {
                editorViewModel.closeSelectedTool()
            },
            onReset: {
                draftState = HostedVideoEditorToolActionCoordinator.reset(
                    tool,
                    currentDraftState: draftState,
                    editorViewModel: editorViewModel,
                    videoPlayer: videoPlayer
                )
            },
            onAppear: {
                draftState = HostedVideoEditorToolActionCoordinator.loadDraftState(
                    for: tool,
                    currentState: draftState,
                    editorViewModel: editorViewModel
                )
            },
            content: {
                if editorViewModel.currentVideo != nil {
                    VideoEditorToolContentView(
                        tool: tool,
                        draftState: $draftState,
                        editorViewModel: editorViewModel
                    )
                } else {
                    EmptyView()
                }
            },
            footer: {
                if VideoEditorToolSheetPresentationPolicy.requiresExplicitApply(tool) {
                    applyFooter(tool)
                }
            }
        )
    }

}

extension ToolsSectionView {

    // MARK: - Private Properties

    private var selectedToolBinding: Binding<ToolEnum?> {
        Binding(
            get: { editorViewModel.presentationState.selectedTool },
            set: { newValue in
                if let newValue {
                    editorViewModel.selectTool(newValue)
                } else {
                    editorViewModel.closeSelectedTool()
                }
            }
        )
    }

    // MARK: - Private Methods

    private func canApply(_ tool: ToolEnum) -> Bool {
        HostedVideoEditorToolActionCoordinator.canApply(
            tool,
            draftState: draftState,
            editorViewModel: editorViewModel
        )
    }

    private func toolbarItemPresentation(
        for tool: ToolEnum,
        currentVideo: Video?,
        cropPresentationSummary: EditorCropPresentationSummary,
        transcriptDocument: TranscriptDocument?
    ) -> EditorToolbarItemPresentation {
        EditorToolbarItemPresentationResolver.resolve(
            for: tool,
            video: currentVideo,
            cropPresentationSummary: cropPresentationSummary,
            transcriptDocument: transcriptDocument
        )
    }

    private func handleToolTap(_ toolAvailability: ToolAvailability) {
        HostedVideoEditorToolActionCoordinator.handleToolTap(
            toolAvailability,
            configuration: configuration,
            editorViewModel: editorViewModel
        )
    }

    private func applyFooter(_ tool: ToolEnum) -> some View {
        let isEnabled = canApply(tool)

        return VStack(spacing: 0) {
            Button {
                applyTool(tool)
            } label: {
                Text(VideoEditorStrings.apply)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Theme.accent.opacity(isEnabled ? 1.0 : 0.45))
                    )
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
        .padding(.top)
        .safeAreaPadding(.horizontal)
    }

    private func applyTool(_ tool: ToolEnum) {
        HostedVideoEditorToolActionCoordinator.apply(
            tool,
            draftState: draftState,
            editorViewModel: editorViewModel,
            videoPlayer: videoPlayer
        )
    }

}

#Preview {
    ToolsSectionViewPreviewHost()
        .padding(.vertical, 24)
        .background(Theme.rootBackground)
}

#Preview("Audio Tool Selected") {
    ToolsSectionViewPreviewHost(initialTool: .audio)
        .padding(.vertical, 24)
        .background(Theme.rootBackground)
}

@MainActor
private struct ToolsSectionViewPreviewHost: View {

    // MARK: - States

    @State private var editorViewModel: EditorViewModel
    @State private var videoPlayer: VideoPlayerManager

    // MARK: - Private Properties

    private let configuration: VideoEditorView.Configuration

    // MARK: - Body

    var body: some View {
        ToolsSectionView(
            videoPlayer,
            editorVM: editorViewModel,
            configuration: configuration
        )
    }

    // MARK: - Initializer

    init(initialTool: ToolEnum? = nil) {
        let editorViewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock

        video.presentationSize = CGSize(width: 1080, height: 1920)
        video.geometrySize = CGSize(width: 1080, height: 1920)
        video.frameSize = CGSize(width: 1080, height: 1920)

        editorViewModel.currentVideo = video
        editorViewModel.handleCurrentVideoChange(
            video,
            videoPlayer: videoPlayer
        )

        if let initialTool {
            editorViewModel.selectTool(initialTool)
        }

        _editorViewModel = State(initialValue: editorViewModel)
        _videoPlayer = State(initialValue: videoPlayer)
        configuration = .init(
            tools: ToolAvailability.enabled(ToolEnum.all)
        )
    }
}
