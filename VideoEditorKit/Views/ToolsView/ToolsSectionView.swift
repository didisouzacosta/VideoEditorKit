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

    // MARK: - Body

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
            ForEach(ToolEnum.menuCases, id: \.self) { tool in
                ToolButtonView(
                    tool.title, image: tool.image,
                    isChange: editorViewModel.currentVideo?.isAppliedTool(for: tool) ?? false
                ) {
                    editorViewModel.selectTool(tool)
                }
            }
        }
        .dynamicHeightSheet(item: selectedToolBinding, initialHeight: initialSheetHeight(for:)) { tool in
            toolSheet(tool)
        }
        .onChange(of: editorViewModel.currentVideo) { _, newValue in
            if newValue == nil {
                selectedToolBinding.wrappedValue = nil
            }
            editorViewModel.handleCurrentVideoChange(
                newValue,
                filtersViewModel: filtersVM,
                textEditor: textEditor
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

    init(_ videoPlayer: VideoPlayerManager, editorVM: EditorViewModel, textEditor: TextEditorViewModel) {
        self.videoPlayer = videoPlayer
        self.editorViewModel = editorVM
        self.textEditor = textEditor
    }

    // MARK: - Private Properties

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

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

                    editorViewModel.closeSelectedTool(textEditor)
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
            AudioToolView(videoPlayer, editorVM: editorViewModel)
        case .text:
            TextToolsView(video, editor: textEditor)
        case .filters:
            FiltersView(video.filterName, viewModel: filtersVM) { filterName in
                editorViewModel.handleFilterChange(
                    filterName,
                    filtersViewModel: filtersVM,
                    videoPlayer: videoPlayer
                )
            }
        case .corrections:
            CorrectionsToolView($filtersVM.colorCorrection) { corrections in
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
        .preferredColorScheme(.dark)
}
