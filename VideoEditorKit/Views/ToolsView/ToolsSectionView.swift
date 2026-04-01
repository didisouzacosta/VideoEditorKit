//
//  ToolsSectionView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import SwiftUI

@MainActor
struct ToolsSectionView: View {

    // MARK: - Private Properties

    private let videoPlayer: VideoPlayerManager
    private let editorViewModel: EditorViewModel
    private let configuration: VideoEditorView.Configuration

    // MARK: - Body

    var body: some View {
        PagedToolsRow(configuration.tools) { tool in
            editorViewModel.currentVideo?.isAppliedTool(for: tool) ?? false
        } action: { toolAvailability in
            handleToolTap(toolAvailability)
        }
        .dynamicHeightSheet(item: selectedToolBinding, initialHeight: initialSheetHeight) { tool in
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

    fileprivate func toolSheet(_ tool: ToolEnum) -> some View {
        Group {
            VStack(spacing: 16) {
                if let video = editorViewModel.currentVideo {
                    toolContent(tool, video)
                }
            }
            .safeAreaPadding()
            .navigationTitle(tool.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        editorViewModel.closeSelectedTool()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        editorViewModel.reset(
                            tool,
                            videoPlayer: videoPlayer
                        )
                    }
                    .disabled(!canReset(tool))
                }
            }
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(contentInteraction(for: tool))
            .presentationCornerRadius(32)
        }
        .modifier(
            CropBackgroundInteractionModifier(
                isEnabled: tool == .presets
            )
        )
    }

}

private struct CropBackgroundInteractionModifier: ViewModifier {

    // MARK: - Public Properties

    let isEnabled: Bool

    // MARK: - Public Methods

    func body(content: Content) -> some View {
        if isEnabled {
            content.presentationBackgroundInteraction(.enabled)
        } else {
            content
        }
    }

}

extension ToolsSectionView {

    // MARK: - Private Methods

    private func initialSheetHeight(for tool: ToolEnum) -> CGFloat {
        switch tool {
        case .audio:
            220
        case .speed:
            260
        case .presets, .corrections:
            300
        case .cut:
            420
        }
    }

    private func contentInteraction(for tool: ToolEnum) -> PresentationContentInteraction {
        switch tool {
        case .audio:
            .resizes
        case .speed, .presets, .corrections, .cut:
            .scrolls
        }
    }

    private func canReset(_ tool: ToolEnum) -> Bool {
        editorViewModel.currentVideo?.isAppliedTool(for: tool) ?? false
    }

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

    private func handleToolTap(_ toolAvailability: ToolAvailability) {
        guard !toolAvailability.isBlocked else {
            configuration.notifyBlockedToolTap(for: toolAvailability.tool)
            return
        }

        editorViewModel.selectTool(toolAvailability.tool)
    }

    @ViewBuilder
    private func toolContent(_ tool: ToolEnum, _ video: Video) -> some View {
        let isAppliedTool = video.isAppliedTool(for: tool)

        switch tool {
        case .speed:
            VideoSpeedToolView(Double(video.rate), isChangeState: isAppliedTool) { rate in
                editorViewModel.handleRateChange(rate, videoPlayer: videoPlayer)
            }
        case .presets:
            PresentToolView(editorViewModel)
        case .audio:
            VideoAudioToolView(videoPlayer, editorVM: editorViewModel)
        case .corrections:
            VideoCorrectionsToolView(
                editorViewModel.exportVideo?.colorCorrection ?? .init()
            ) { corrections in
                editorViewModel.setCorrections(corrections)
                videoPlayer.setColorCorrection(corrections)
            }
        case .cut:
            EmptyView()
        }
    }

}

#Preview {
    VideoEditorView()
}
