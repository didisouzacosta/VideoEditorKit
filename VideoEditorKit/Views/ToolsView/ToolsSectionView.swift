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

    private enum Constants {
        static let settleAnimation = Animation.smooth(
            duration: 0.28,
            extraBounce: 0.04
        )
        static let transcriptSheetHeight: CGFloat = 520
    }

    // MARK: - States

    @State private var speedDraft = 1.0
    @State private var adjustsDraft = ColorAdjusts()
    @State private var presetDraft: VideoCropFormatPreset = .original
    @State private var audioDraft = AudioToolDraft()

    // MARK: - Private Properties

    private let videoPlayer: VideoPlayerManager
    private let editorViewModel: EditorViewModel
    private let configuration: VideoEditorView.Configuration

    // MARK: - Body

    var body: some View {
        let appliedToolIDs = Set(editorViewModel.currentVideo?.toolsApplied ?? [])

        PagedToolsRow(configuration.tools) { tool in
            appliedToolIDs.contains(tool.rawValue)
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
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                if let video = editorViewModel.currentVideo {
                    toolContent(tool, video)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, requiresExplicitApply(tool) ? 20 : 24)

            if requiresExplicitApply(tool) {
                applyFooter(tool)
            }
        }
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
                    resetTool(tool)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(contentInteraction(for: tool))
        .presentationCornerRadius(32)
        .onAppear {
            loadDraft(for: tool)
        }
        .modifier(
            CropBackgroundInteractionModifier(
                isEnabled: false
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
            300
        case .speed:
            320
        case .presets, .adjusts:
            380
        case .transcript:
            Constants.transcriptSheetHeight
        case .cut:
            420
        }
    }

    private func contentInteraction(for tool: ToolEnum) -> PresentationContentInteraction {
        switch tool {
        case .audio, .speed, .presets, .adjusts:
            .resizes
        case .transcript, .cut:
            .scrolls
        }
    }

    private func requiresExplicitApply(_ tool: ToolEnum) -> Bool {
        switch tool {
        case .speed, .presets, .audio, .adjusts:
            true
        case .transcript, .cut:
            false
        }
    }

    private func canApply(_ tool: ToolEnum) -> Bool {
        guard let video = editorViewModel.currentVideo else { return false }

        switch tool {
        case .speed:
            return abs(Double(video.rate) - speedDraft) > 0.001
        case .presets:
            return editorViewModel.cropPresentationSummary.selectedPreset != presetDraft
        case .audio:
            return audioDraft
                != AudioToolDraft(
                    video: video,
                    selectedTrack: editorViewModel.presentationState.selectedAudioTrack
                )
        case .adjusts:
            return video.colorAdjusts != adjustsDraft
        case .transcript, .cut:
            return false
        }
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
        switch tool {
        case .speed:
            VideoSpeedToolView($speedDraft)
        case .presets:
            PresentToolView(
                selectedPreset: $presetDraft,
                onSelect: { presetDraft = $0 }
            )
        case .audio:
            VideoAudioToolView(
                draft: $audioDraft,
                hasRecordedAudioTrack: editorViewModel.hasRecordedAudioTrack
            )
        case .adjusts:
            VideoAdjustsToolView($adjustsDraft)
        case .transcript:
            TranscriptToolView(
                transcriptState: editorViewModel.transcriptState,
                document: editorViewModel.transcriptDocument,
                onTranscribe: {
                    editorViewModel.transcribeCurrentVideo()
                },
                onRetry: {
                    editorViewModel.transcribeCurrentVideo()
                },
                onUpdateSegmentText: { segmentID, text in
                    editorViewModel.updateTranscriptSegmentText(
                        text,
                        segmentID: segmentID
                    )
                },
                onUpdateSegmentStyle: { segmentID, styleID in
                    editorViewModel.updateTranscriptSegmentStyle(
                        styleID,
                        segmentID: segmentID
                    )
                }
            )
        case .cut:
            EmptyView()
        }
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

    private func loadDraft(for tool: ToolEnum) {
        guard let video = editorViewModel.currentVideo else { return }

        switch tool {
        case .speed:
            speedDraft = Double(video.rate)
        case .presets:
            presetDraft = editorViewModel.cropPresentationSummary.selectedPreset
        case .audio:
            audioDraft = AudioToolDraft(
                video: video,
                selectedTrack: editorViewModel.presentationState.selectedAudioTrack
            )
        case .adjusts:
            adjustsDraft = video.colorAdjusts
        case .transcript:
            break
        case .cut:
            break
        }
    }

    private func resetTool(_ tool: ToolEnum) {
        if tool == .presets {
            withAnimation(Constants.settleAnimation) {
                editorViewModel.reset(
                    tool,
                    videoPlayer: videoPlayer
                )
            }
        } else if tool == .transcript {
            editorViewModel.resetTranscript()
        } else {
            editorViewModel.reset(
                tool,
                videoPlayer: videoPlayer
            )
        }
        loadDraft(for: tool)
        editorViewModel.closeSelectedTool()
    }

    private func applyTool(_ tool: ToolEnum) {
        guard let video = editorViewModel.currentVideo else { return }

        switch tool {
        case .speed:
            editorViewModel.handleRateChange(
                Float(speedDraft),
                videoPlayer: videoPlayer
            )
            editorViewModel.closeSelectedTool()
        case .presets:
            if presetDraft == editorViewModel.cropPresentationSummary.selectedPreset {
                editorViewModel.closeSelectedTool()
            } else {
                withAnimation(Constants.settleAnimation) {
                    editorViewModel.selectCropFormat(presetDraft)
                }
            }
        case .audio:
            let committedAudioDraft = AudioToolDraft(
                video: video,
                selectedTrack: editorViewModel.presentationState.selectedAudioTrack
            )

            guard audioDraft != committedAudioDraft else {
                editorViewModel.closeSelectedTool()
                return
            }

            editorViewModel.selectAudioTrack(audioDraft.selectedTrack)
            commitAudioVolumeIfNeeded(
                committedValue: video.volume,
                draftValue: audioDraft.videoVolume,
                track: .video
            )

            if video.audio != nil {
                commitAudioVolumeIfNeeded(
                    committedValue: video.audio?.volume ?? 1,
                    draftValue: audioDraft.recordedVolume,
                    track: .recorded
                )
            }

            editorViewModel.selectAudioTrack(audioDraft.selectedTrack)
            editorViewModel.closeSelectedTool()
        case .adjusts:
            guard adjustsDraft != video.colorAdjusts else {
                editorViewModel.closeSelectedTool()
                return
            }

            editorViewModel.setAdjusts(adjustsDraft)
            videoPlayer.setColorAdjusts(adjustsDraft)
            editorViewModel.closeSelectedTool()
        case .transcript:
            break
        case .cut:
            break
        }
    }

    private func commitAudioVolumeIfNeeded(
        committedValue: Float,
        draftValue: Float,
        track: VideoEditingConfiguration.SelectedTrack
    ) {
        guard abs(Double(committedValue - draftValue)) > 0.001 else { return }

        editorViewModel.selectAudioTrack(track)
        editorViewModel.updateSelectedTrackVolume(
            draftValue,
            videoPlayer: videoPlayer
        )
    }

}

#Preview {
    VideoEditorView()
}
