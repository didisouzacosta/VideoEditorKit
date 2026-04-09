#if os(iOS)
    import SwiftUI

    @MainActor
    struct ToolsSectionView: View {

        // MARK: - States

        @State private var draftState = EditorToolDraftState()

        // MARK: - Private Properties

        private let videoPlayer: VideoPlayerManager
        private let editorViewModel: EditorViewModel
        private let configuration: VideoEditorView.Configuration

        // MARK: - Body

        var body: some View {
            let cropPresentationSummary = editorViewModel.cropPresentationSummary

            VideoEditorToolsTrayView(
                selectedTool: selectedToolBinding,
                initialSheetHeight: VideoEditorToolSheetPresentationPolicy.initialSheetHeight(for:)
            ) {
                PagedToolsRow(configuration.tools) { tool in
                    toolbarItemPresentation(
                        for: tool,
                        cropPresentationSummary: cropPresentationSummary
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
            cropPresentationSummary: EditorCropPresentationSummary
        ) -> EditorToolbarItemPresentation {
            HostedVideoEditorToolActionCoordinator.toolbarItemPresentation(
                for: tool,
                cropPresentationSummary: cropPresentationSummary,
                editorViewModel: editorViewModel
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
                    Text("Apply")
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
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
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
        VideoEditorView(
            "Preview",
            session: VideoEditorSession(source: nil)
        )
    }

#endif
