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
    private let editorVM: EditorViewModel
    private let textEditor: TextEditorViewModel

    // MARK: - Body

    var body: some View {
        ZStack {
            LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
                ForEach(ToolEnum.menuCases, id: \.self) { tool in
                    ToolButtonView(
                        tool.title, image: tool.image,
                        isChange: editorVM.currentVideo?.isAppliedTool(for: tool) ?? false
                    ) {
                        editorVM.selectTool(tool)
                    }
                }
            }
            .opacity(editorVM.toolGridOpacity)

            if let toolState = editorVM.selectedTools, let video = editorVM.currentVideo {
                bottomSheet(toolState, video)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeIn(duration: 0.15), value: editorVM.selectedTools)
        .onChange(of: editorVM.currentVideo) { _, newValue in
            editorVM.handleCurrentVideoChange(
                newValue,
                filtersViewModel: filtersVM,
                textEditor: textEditor
            )
        }
        .onChange(of: editorVM.currentVideo?.thumbnailsImages.count ?? 0) { _, _ in
            editorVM.handleThumbnailImagesChange(filtersViewModel: filtersVM)
        }
        .onChange(of: textEditor.selectedTextBox) { _, box in
            editorVM.handleSelectedTextBoxChange(box)
        }
        .onChange(of: editorVM.selectedTools) { _, newValue in
            editorVM.handleSelectedToolChange(newValue, textEditor: textEditor)
        }
    }

    // MARK: - Initializer

    init(_ videoPlayer: VideoPlayerManager, editorVM: EditorViewModel, textEditor: TextEditorViewModel) {
        self.videoPlayer = videoPlayer
        self.editorVM = editorVM
        self.textEditor = textEditor
    }

    // MARK: - Private Properties

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

}

extension ToolsSectionView {

    // MARK: - Private Methods

    @ViewBuilder
    private func bottomSheet(_ tool: ToolEnum, _ video: Video) -> some View {

        let isAppliedTool = video.isAppliedTool(for: tool)

        VStack(spacing: 16) {
            sheetHeader(tool)
            switch tool {
            case .speed:
                VideoSpeedSlider(Double(video.rate), isChangeState: isAppliedTool) { rate in
                    editorVM.handleRateChange(rate, videoPlayer: videoPlayer)
                }
            case .crop:
                CropSheetView(editorVM)
            case .audio:
                AudioSheetView(videoPlayer, editorVM: editorVM)
            case .text:
                TextToolsView(video, editor: textEditor)
            case .filters:
                FiltersView(video.filterName, viewModel: filtersVM) { filterName in
                    editorVM.handleFilterChange(
                        filterName,
                        filtersViewModel: filtersVM,
                        videoPlayer: videoPlayer
                    )
                }
            case .corrections:
                CorrectionsToolView($filtersVM.colorCorrection) { corrections in
                    editorVM.handleCorrectionsChange(corrections, videoPlayer: videoPlayer)
                }
            case .frames:
                FramesToolView(
                    editorVM.frameColorBinding(),
                    scaleValue: editorVM.frameScaleBinding(),
                    onChange: editorVM.setFrames)
            case .cut:
                EmptyView()
            }
            Spacer()
        }
        .padding(16)
        .card(cornerRadius: 30, prominent: true, tint: Theme.secondary)
    }

}

extension ToolsSectionView {

    // MARK: - Private Methods

    private func sheetHeader(_ tool: ToolEnum) -> some View {
        HStack {
            Button {
                editorVM.closeSelectedTool(textEditor: textEditor)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .circleControl()
            }
            .buttonStyle(.plain)

            Spacer()
            if editorVM.canReset(tool) {
                Button {
                    editorVM.reset()
                } label: {
                    Text("Reset")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .capsuleControl()
                }
                .buttonStyle(.plain)
            } else if editorVM.canRemoveAudio(for: tool) {
                Button {
                    editorVM.removeAudio(using: videoPlayer)
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.headline.weight(.semibold))
                        .frame(width: 40, height: 40)
                        .circleControl()
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            Text(tool.title)
                .font(.headline)
        }
    }

}

#Preview {
    VideoEditorView()
        .preferredColorScheme(.dark)
}
