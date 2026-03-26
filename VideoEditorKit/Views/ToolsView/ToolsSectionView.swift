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
    @State private var selectedDetent: PresentationDetent = .medium

    // MARK: - Private Properties

    private let videoPlayer: VideoPlayerManager
    private let editorVM: EditorViewModel
    private let textEditor: TextEditorViewModel

    // MARK: - Body

    var body: some View {
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
        .sheet(item: selectedToolBinding) { tool in
            toolSheet(tool)
        }
        .onChange(of: editorVM.currentVideo) { _, newValue in
            if newValue == nil {
                selectedToolBinding.wrappedValue = nil
            }
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
            handleSelectedToolChange(newValue)
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

    private func toolSheet(_ tool: ToolEnum) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let video = editorVM.currentVideo {
                    toolContent(tool, video)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .navigationTitle(tool.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editorVM.closeSelectedTool(textEditor: textEditor)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        editorVM.reset(
                            tool,
                            textEditor: textEditor,
                            videoPlayer: videoPlayer
                        )
                    }
                }
            }
        }
        .presentationDetents(detents(for: tool), selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(contentInteraction(for: tool))
        .presentationCornerRadius(32)
    }

}

extension ToolsSectionView {

    // MARK: - Private Methods

    private func detents(for tool: ToolEnum) -> Set<PresentationDetent> {
        switch tool {
        case .audio:
            [.height(220)]
        case .filters, .text:
            [.height(220), .medium]
        case .speed:
            [.height(260), .medium]
        case .crop, .corrections:
            [.height(300), .medium]
        case .frames:
            [.height(340), .medium]
        case .cut:
            [.medium]
        }
    }

    private func defaultDetent(for tool: ToolEnum) -> PresentationDetent {
        switch tool {
        case .audio, .filters, .text:
            .height(220)
        case .speed:
            .height(260)
        case .crop, .corrections:
            .height(300)
        case .frames:
            .height(340)
        case .cut:
            .medium
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

    private var selectedToolBinding: Binding<ToolEnum?> {
        Binding(
            get: { editorVM.selectedTools },
            set: { newValue in
                if let newValue {
                    editorVM.selectTool(newValue)
                } else {
                    editorVM.closeSelectedTool(textEditor: textEditor)
                }
            }
        )
    }

    private func handleSelectedToolChange(_ tool: ToolEnum?) {
        if let tool {
            selectedDetent = defaultDetent(for: tool)
        }

        editorVM.handleSelectedToolChange(tool, textEditor: textEditor)
    }

    @ViewBuilder
    private func toolContent(_ tool: ToolEnum, _ video: Video) -> some View {
        let isAppliedTool = video.isAppliedTool(for: tool)

        switch tool {
        case .speed:
            VideoSpeedSlider(Double(video.rate), isChangeState: isAppliedTool) { rate in
                editorVM.handleRateChange(rate, videoPlayer: videoPlayer)
            }
        case .crop:
            CropToolView(editorVM)
        case .audio:
            AudioToolView(videoPlayer, editorVM: editorVM)
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
                onChange: editorVM.setFrames
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
