//
//  PlayerHolderView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Observation
import SwiftUI

@MainActor
struct PlayerHolderView: View {

    private enum Constants {
        static let settleAnimation = Animation.smooth(
            duration: 0.28,
            extraBounce: 0.04
        )
    }

    // MARK: - Environments

    @Environment(\.displayScale) private var displayScale

    // MARK: - States

    @State private var presentedSafeAreaGuideInfo: SafeAreaGuideInfo?

    // MARK: - Private Properties

    private let editorViewModel: EditorViewModel
    private let videoPlayer: VideoPlayerManager

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                switch videoPlayer.loadState {
                case .loading:
                    ProgressView()
                case .unknown:
                    statusView("Add a video to start editing")
                case .failed:
                    statusView("Failed to open video")
                case .loaded:
                    playerCropView
                }
            }
            .allFrame()
        }
    }

    // MARK: - Initializer

    init(
        _ editorViewModel: EditorViewModel,
        videoPlayer: VideoPlayerManager
    ) {
        self.editorViewModel = editorViewModel
        self.videoPlayer = videoPlayer
    }

}

extension PlayerHolderView {

    // MARK: - Private Properties

    private var playerCropView: some View {
        Group {
            if let video = editorViewModel.currentVideo {
                let cropSummary = editorViewModel.cropPresentationSummary(
                    isPlaybackFocused: videoPlayer.isPlaybackFocusActive
                )

                GeometryReader { proxy in
                    VideoCanvasPreviewView(
                        editorViewModel.cropPresentationState.canvasEditorState,
                        source: editorViewModel.videoCanvasSource(for: video),
                        isInteractive: cropSummary.isCropOverlayInteractive,
                        cornerRadius: 16,
                        onInteractionStarted: {
                            videoPlayer.beginPlaybackInteraction()
                        },
                        onInteractionEnded: { _ in
                            videoPlayer.endPlaybackInteraction()
                        },
                        onSnapshotChange: { _ in
                            editorViewModel.handleCanvasPreviewChange()
                        }
                    ) {
                        ZStack {
                            editorViewModel.frames.frameColor

                            PlayerView(videoPlayer.videoPlayer)
                                .allFrame()
                                .scaleEffect(editorViewModel.frames.scale)
                                .animation(
                                    Constants.settleAnimation,
                                    value: editorViewModel.frames.scale
                                )
                        }
                    } overlay: {
                        Color.clear
                            .allFrame()
                            .overlay {
                                if let profile = cropSummary.activeSafeAreaGuideProfile {
                                    SafeAreaOverlayView(
                                        profile: profile,
                                        cornerRadius: 16
                                    )
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if cropSummary.shouldShowCropPresetBadge {
                                    cropPresetBadge(cropSummary)
                                        .padding(.bottom, 16)
                                        .allowsHitTesting(false)
                                }
                            }
                            .overlay(alignment: .bottomTrailing) {
                                trailingPlayerControls(cropSummary)
                                    .padding(.trailing, 16)
                                    .padding(.bottom, 16)
                            }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .task(
                        id: playerLayoutID(
                            for: proxy.size,
                            rotation: video.rotation,
                            videoID: video.id,
                            canvasPreset: editorViewModel.cropPresentationState.canvasEditorState.preset,
                            freeCanvasSize: editorViewModel.cropPresentationState.canvasEditorState.freeCanvasSize
                        )
                    ) {
                        syncVideoLayout(for: proxy.size)
                    }
                }
            }
        }
        .sheet(item: $presentedSafeAreaGuideInfo) { guideInfo in
            SafeAreaGuideInfoSheet(guideInfo)
                .presentationDetents([.height(240)])
                .presentationDragIndicator(.visible)
        }
    }

    private func cropPresetBadge(
        _ cropSummary: EditorCropPresentationSummary
    ) -> some View {
        Text(cropSummary.badgeText)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .capsuleControl(
                prominent: true,
                tint: .black.opacity(0.82)
            )
            .foregroundStyle(.white)
    }

    private var resetCanvasButton: some View {
        Button {
            withAnimation(Constants.settleAnimation) {
                editorViewModel.resetCanvasTransform()
            }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(14)
                .circleControl(
                    prominent: true,
                    tint: .black.opacity(0.82)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset transform")
    }

    @ViewBuilder
    private func trailingPlayerControls(
        _ cropSummary: EditorCropPresentationSummary
    ) -> some View {
        if cropSummary.shouldShowCanvasResetButton || cropSummary.availableSafeAreaGuideProfile != nil {
            VStack(alignment: .trailing, spacing: 10) {
                if let profile = cropSummary.availableSafeAreaGuideProfile {
                    safeAreaGuideControls(
                        profile,
                        isVisible: cropSummary.shouldShowSafeAreaOverlay
                    )
                }

                if cropSummary.shouldShowCanvasResetButton {
                    resetCanvasButton
                }
            }
        }
    }

    private func safeAreaGuideControls(
        _ profile: SafeAreaGuideProfile,
        isVisible: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                presentedSafeAreaGuideInfo = .init(profile: profile)
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .circleControl(
                        prominent: true,
                        tint: .black.opacity(0.82)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Explain safe area")

            Button {
                withAnimation(Constants.settleAnimation) {
                    editorViewModel.toggleSafeAreaOverlay()
                }
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .circleControl(
                        prominent: true,
                        tint: isVisible ? .green.opacity(0.72) : .black.opacity(0.82)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Hide safe area" : "Show safe area")
        }
    }

    // MARK: - Private Methods

    private func statusView(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .capsuleControl()
    }

    private func playerLayoutID(
        for containerSize: CGSize,
        rotation: Double,
        videoID: UUID,
        canvasPreset: VideoCanvasPreset,
        freeCanvasSize: CGSize
    ) -> String {
        "\(videoID.uuidString)-\(Int(containerSize.width.rounded()))-\(Int(containerSize.height.rounded()))-\(Int(rotation))-\(String(describing: canvasPreset))-\(Int(freeCanvasSize.width.rounded()))-\(Int(freeCanvasSize.height.rounded()))"
    }

    private func syncVideoLayout(for containerSize: CGSize) {
        guard let video = editorViewModel.currentVideo else { return }

        let size = editorViewModel.cropPresentationState.canvasEditorState.previewLayout(
            source: editorViewModel.videoCanvasSource(for: video),
            availableSize: containerSize
        ).previewCanvasSize

        guard size.width > 0, size.height > 0 else { return }
        guard editorViewModel.currentVideo?.id == video.id else { return }

        editorViewModel.updateCurrentVideoLayout(
            to: size
        )
    }

}

private struct SafeAreaGuideInfo: Identifiable {

    // MARK: - Public Properties

    let profile: SafeAreaGuideProfile

    var id: String {
        switch profile {
        case .universalSocial:
            "universal-social"
        case .platform(let platform):
            platform.rawValue
        }
    }

}

private struct SafeAreaGuideInfoSheet: View {

    // MARK: - Environments

    @Environment(\.dismiss) private var dismiss

    // MARK: - Private Properties

    private let guideInfo: SafeAreaGuideInfo

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(guideInfo.profile.explanation)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(
                    "Keep titles, people, logos and CTAs inside the highlighted frame for better platform readability."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(guideInfo.profile.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Initializer

    init(_ guideInfo: SafeAreaGuideInfo) {
        self.guideInfo = guideInfo
    }

}

@MainActor
struct PlayerControl: View {

    // MARK: - Environments

    @Environment(\.displayScale) private var displayScale

    // MARK: - Private Properties

    private let editorViewModel: EditorViewModel
    private let videoPlayer: VideoPlayerManager
    private let recorderManager: AudioRecorderManager

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        if let video = editorViewModel.currentVideo {
            playbackTimelineSection(video)
        }
    }

    // MARK: - Initializer

    init(
        _ editorViewModel: EditorViewModel,
        videoPlayer: VideoPlayerManager,
        recorderManager: AudioRecorderManager
    ) {
        self.editorViewModel = editorViewModel
        self.videoPlayer = videoPlayer
        self.recorderManager = recorderManager
    }

    // MARK: - Private Methods

    private func playbackTimelineSection(_ video: Video) -> some View {
        trimSection(video)
    }

    private func trimSection(_ video: Video) -> some View {
        ThumbnailsSliderView(
            videoPlayer.currentTimeBinding(),
            video: .init(
                get: { editorViewModel.currentVideo },
                set: { editorViewModel.currentVideo = $0 }
            ),
            isPlaying: videoPlayer.isPlaying,
            isChangeState: video.isAppliedTool(for: .cut),
            onPlayPauseTapped: {
                if let video = editorViewModel.currentVideo {
                    videoPlayer.action(video)
                }
            },
            onChangeTimeValue: { newRange in
                videoPlayer.updatePlaybackRange(newRange)
                editorViewModel.setCut()
            },
            onRequestThumbnails: { size in
                editorViewModel.refreshThumbnailsIfNeeded(
                    containerSize: size,
                    displayScale: displayScale
                )
            },
            onTrimRangeInteractionStarted: {
                videoPlayer.beginPlaybackInteraction()
            },
            onTrimRangeInteractionEnded: { time, range in
                videoPlayer.endPlaybackInteraction(
                    resumeAt: time,
                    in: range
                )
            },
            onPlaybackScrubStarted: { range in
                videoPlayer.beginScrubbing(in: range)
            },
            onPlaybackScrubChanged: { time, range in
                videoPlayer.scrub(
                    to: time,
                    in: range
                )
            },
            onPlaybackScrubEnded: { time, range in
                videoPlayer.endScrubbing(
                    at: time,
                    in: range
                )
            }
        )
    }

}

#Preview {
    VideoEditorView()
}
