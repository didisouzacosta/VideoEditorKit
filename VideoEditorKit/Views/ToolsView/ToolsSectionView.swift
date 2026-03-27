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

    // MARK: - States

    @State private var filtersVM = FiltersViewModel()

    // MARK: - Private Properties

    private let videoPlayer: VideoPlayerManager
    private let editorViewModel: EditorViewModel
    private let textEditor: TextEditorViewModel
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
                filtersViewModel: filtersVM,
                textEditor: textEditor,
                videoPlayer: videoPlayer
            )
        }
        .onChange(of: editorViewModel.currentVideo?.thumbnailsImages.count ?? 0) { _, _ in
            editorViewModel.handleThumbnailImagesChange(filtersViewModel: filtersVM)
        }
        .onChange(of: textEditor.selectedTextBox) { _, box in
            editorViewModel.handleSelectedTextBoxChange(box)
        }
        .onChange(of: editorViewModel.selectedTools) { _, newValue in
            handleSelectedToolChange(newValue)
        }
    }

    // MARK: - Initializer

    init(
        _ videoPlayer: VideoPlayerManager,
        editorVM: EditorViewModel,
        textEditor: TextEditorViewModel,
        configuration: VideoEditorView.Configuration
    ) {
        self.videoPlayer = videoPlayer
        self.editorViewModel = editorVM
        self.textEditor = textEditor
        self.configuration = configuration
    }

}

extension ToolsSectionView {

    fileprivate func toolSheet(_ tool: ToolEnum) -> some View {
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
                    editorViewModel.closeSelectedTool(textEditor)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    if tool == .corrections {
                        filtersVM.colorCorrection = ColorCorrection()
                    }

                    editorViewModel.reset(
                        tool,
                        textEditor: textEditor,
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

}

extension ToolsSectionView {

    // MARK: - Private Methods

    private func initialSheetHeight(for tool: ToolEnum) -> CGFloat {
        switch tool {
        case .audio, .filters, .text:
            220
        case .speed:
            260
        case .crop, .corrections:
            300
        case .frames:
            340
        case .cut:
            420
        }
    }

    private func contentInteraction(for tool: ToolEnum) -> PresentationContentInteraction {
        switch tool {
        case .audio:
            .resizes
        case .speed, .crop, .text, .filters, .corrections, .frames, .cut:
            .scrolls
        }
    }

    private func canReset(_ tool: ToolEnum) -> Bool {
        editorViewModel.currentVideo?.isAppliedTool(for: tool) ?? false
    }

    // MARK: - Private Properties

    private var selectedToolBinding: Binding<ToolEnum?> {
        Binding(
            get: { editorViewModel.selectedTools },
            set: { newValue in
                if let newValue {
                    editorViewModel.selectTool(newValue)
                } else {
                    editorViewModel.closeSelectedTool(textEditor)
                }
            }
        )
    }

    // MARK: - Private Methods

    private func handleSelectedToolChange(_ tool: ToolEnum?) {
        editorViewModel.handleSelectedToolChange(tool, textEditor: textEditor)
    }

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
        case .crop:
            CropToolView(editorViewModel)
        case .audio:
            VideoAudioToolView(videoPlayer, editorVM: editorViewModel)
        case .text:
            TextToolsView(video, editor: textEditor)
        case .filters:
            VideoFiltersToolView(video.filterName, viewModel: filtersVM) { filterName in
                editorViewModel.handleFilterChange(
                    filterName,
                    filtersViewModel: filtersVM,
                    videoPlayer: videoPlayer
                )
            }
        case .corrections:
            VideoCorrectionsToolView($filtersVM.colorCorrection) { corrections in
                editorViewModel.handleCorrectionsChange(corrections, videoPlayer: videoPlayer)
            }
        case .frames:
            FramesToolView(
                editorViewModel.frameColorBinding(),
                scaleValue: editorViewModel.frameScaleBinding(),
                onChange: editorViewModel.setFrames
            )
        case .cut:
            EmptyView()
        }
    }

}

#Preview {
    VideoEditorView()
}
