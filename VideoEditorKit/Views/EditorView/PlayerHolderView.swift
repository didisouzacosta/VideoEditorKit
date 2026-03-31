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

    // MARK: - Environments

    @Environment(\.displayScale) private var displayScale

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
                GeometryReader { proxy in
                    let spotlightMode = editorViewModel.shouldUseCropPresetSpotlight

                    VideoCanvasPreviewView(
                        editorViewModel.canvasEditorState,
                        source: editorViewModel.videoCanvasSource(for: video),
                        isInteractive: editorViewModel.isCropOverlayInteractive,
                        cornerRadius: spotlightMode ? 28 : 4,
                        onSnapshotChange: { _ in
                            editorViewModel.handleCanvasPreviewChange()
                        }
                    ) {
                        ZStack {
                            editorViewModel.frames.frameColor

                            PlayerView(videoPlayer.videoPlayer)
                                .allFrame()
                                .scaleEffect(editorViewModel.frames.scale)
                        }
                    } overlay: {
                        ZStack(alignment: .bottom) {
                            if let platform = editorViewModel.activeSafeAreaPlatform {
                                SafeAreaOverlayView(
                                    platform: platform,
                                    cornerRadius: spotlightMode ? 28 : 4
                                )
                            }

                            if editorViewModel.shouldShowCropPresetBadge() {
                                cropPresetBadge
                                    .padding(.bottom, spotlightMode ? 16 : 12)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .shadow(
                        color: .black.opacity(spotlightMode ? 0.18 : 0),
                        radius: spotlightMode ? 28 : 0,
                        y: spotlightMode ? 18 : 0
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .task(
                        id: playerLayoutID(
                            for: proxy.size,
                            rotation: video.rotation,
                            videoID: video.id,
                            changeCounter: editorViewModel.editingConfigurationChangeCounter
                        )
                    ) {
                        await syncVideoLayout(for: proxy.size)
                    }
                }
            }
        }
    }

    private var cropPresetBadge: some View {
        Text(
            "\(editorViewModel.selectedCropPresetBadgeTitle()) • \(editorViewModel.selectedCropPresetBadgeDimension())"
        )
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .capsuleControl(
            prominent: true,
            tint: .black.opacity(0.82)
        )
        .foregroundStyle(.white)
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
        changeCounter: Int
    ) -> String {
        "\(videoID.uuidString)-\(Int(containerSize.width.rounded()))-\(Int(containerSize.height.rounded()))-\(Int(rotation))-\(changeCounter)"
    }

    private func syncVideoLayout(for containerSize: CGSize) async {
        guard let video = editorViewModel.currentVideo else { return }

        let size = await editorViewModel.canvasEditorState.previewLayout(
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
            }
        ) { newRange in
            videoPlayer.pause()
            videoPlayer.updatePlaybackRange(newRange)
            editorViewModel.setCut()
        } onRequestThumbnails: { size in
            editorViewModel.refreshThumbnailsIfNeeded(
                containerSize: size,
                displayScale: displayScale
            )
        } onPlaybackScrubStarted: { range in
            videoPlayer.beginScrubbing(in: range)
        } onPlaybackScrubChanged: { time, range in
            videoPlayer.scrub(
                to: time,
                in: range
            )
        } onPlaybackScrubEnded: { time, range in
            videoPlayer.endScrubbing(
                at: time,
                in: range
            )
        }
    }

}

#Preview {
    VideoEditorView()
}
