//
//  ToolsSectionView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import Observation
import SwiftUI

@MainActor
struct ToolsSectionView: View {
    @State private var filtersVM = FiltersViewModel()
    @Bindable var videoPlayer: VideoPlayerManager
    @Bindable var editorVM: EditorViewModel
    let textEditor: TextEditorViewModel
    private let columns = Array(repeating: GridItem(.flexible()), count: 4)
    var body: some View {
        ZStack {
            LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
                ForEach(ToolEnum.menuCases, id: \.self) { tool in
                    ToolButtonView(
                        label: tool.title, image: tool.image,
                        isChange: editorVM.currentVideo?.isAppliedTool(for: tool) ?? false
                    ) {
                        editorVM.selectedTools = tool
                    }
                }
            }
            .opacity(editorVM.selectedTools != nil ? 0 : 1)

            if let toolState = editorVM.selectedTools, let video = editorVM.currentVideo {
                bottomSheet(toolState, video)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeIn(duration: 0.15), value: editorVM.selectedTools)
        .onChange(of: editorVM.currentVideo) { _, newValue in
            if let video = newValue {
                filtersVM.colorCorrection = video.colorCorrection
                textEditor.textBoxes = video.textBoxes
            }
        }
        .onChange(of: editorVM.currentVideo?.thumbnailsImages.count ?? 0) { _, newValue in
            guard newValue > 0,
                let image = editorVM.currentVideo?.thumbnailsImages.first?.image
            else {
                return
            }

            filtersVM.loadFilters(for: image)
        }
        .onChange(of: textEditor.selectedTextBox) { _, box in
            if box != nil {
                if editorVM.selectedTools != .text {
                    editorVM.selectedTools = .text
                }
            } else {
                editorVM.selectedTools = nil
            }
        }
        .onChange(of: editorVM.selectedTools) { _, newValue in
            if newValue == .text, textEditor.textBoxes.isEmpty {
                textEditor.openTextEditor(isEdit: false, timeRange: editorVM.currentVideo?.rangeDuration)
            }

            if newValue == nil {
                editorVM.setText(textEditor.textBoxes)
            }
        }
    }
}

extension ToolsSectionView {

    @ViewBuilder
    private func bottomSheet(_ tool: ToolEnum, _ video: Video) -> some View {

        let isAppliedTool = video.isAppliedTool(for: tool)

        VStack(spacing: 16) {
            sheetHeader(tool)
            switch tool {
            case .speed:
                VideoSpeedSlider(value: Double(video.rate), isChangeState: isAppliedTool) { rate in
                    videoPlayer.pause()
                    editorVM.updateRate(rate: rate)
                }
            case .crop:
                CropSheetView(editorVM: editorVM)
            case .audio:
                AudioSheetView(videoPlayer: videoPlayer, editorVM: editorVM)
            case .text:
                TextToolsView(video: video, editor: textEditor)
            case .filters:
                FiltersView(selectedFilterName: video.filterName, viewModel: filtersVM) { filterName in
                    if let filterName {
                        videoPlayer.setFilters(
                            mainFilter: CIFilter(name: filterName), colorCorrection: filtersVM.colorCorrection)
                    } else {
                        videoPlayer.removeFilter()
                    }
                    editorVM.setFilter(filterName)
                }
            case .corrections:
                CorrectionsToolView(correction: $filtersVM.colorCorrection) { corrections in
                    videoPlayer.setFilters(
                        mainFilter: CIFilter(name: video.filterName ?? ""), colorCorrection: corrections)
                    editorVM.setCorrections(corrections)
                }
            case .frames:
                FramesToolView(
                    selectedColor: $editorVM.frames.frameColor, scaleValue: $editorVM.frames.scaleValue,
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

    private func sheetHeader(_ tool: ToolEnum) -> some View {
        HStack {
            Button {
                editorVM.selectedTools = nil
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .circleControl()
            }
            .buttonStyle(.plain)

            Spacer()
            if tool != .filters, tool != .audio, tool != .text {
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
            } else if !editorVM.isSelectVideo {
                Button {
                    videoPlayer.pause()
                    editorVM.removeAudio()
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
    MainEditorView()
        .preferredColorScheme(.dark)
}
