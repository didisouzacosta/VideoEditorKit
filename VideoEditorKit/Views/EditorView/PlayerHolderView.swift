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
    private let textEditor: TextEditorViewModel

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
        videoPlayer: VideoPlayerManager,
        textEditor: TextEditorViewModel
    ) {
        self.editorViewModel = editorViewModel
        self.videoPlayer = videoPlayer
        self.textEditor = textEditor
    }

}

extension PlayerHolderView {

    // MARK: - Private Properties

    private var playerCropView: some View {
        Group {
            if let video = editorViewModel.currentVideo {
                GeometryReader { proxy in
                    let displaySize = editorViewModel.resolvedPlayerDisplaySize(
                        for: video,
                        in: proxy.size
                    )

                    ZStack {
                        CropView(
                            displaySize,
                            freeformRect: Binding(
                                get: { editorViewModel.cropFreeformRect },
                                set: { editorViewModel.setCropFreeformRect($0) }
                            ),
                            rotation: editorViewModel.currentVideo?.rotation,
                            isMirror: editorViewModel.currentVideo?.isMirror ?? false,
                            isActiveCrop: editorViewModel.selectedTools == .crop
                        ) {
                            ZStack {
                                editorViewModel.frames.frameColor

                                ZStack {
                                    PlayerView(videoPlayer.videoPlayer)
                                    TextOverlayView(
                                        videoPlayer.currentTime,
                                        viewModel: textEditor
                                    )
                                }
                                .scaleEffect(editorViewModel.frames.scale)
                            }
                        }
                        .frame(width: displaySize.width, height: displaySize.height)
                        .clipShape(.rect(cornerRadius: 4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .task(
                        id: playerLayoutID(
                            for: proxy.size,
                            rotation: video.rotation,
                            videoID: video.id
                        )
                    ) {
                        syncVideoLayout(for: proxy.size)
                    }
                }
            }
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
        videoID: UUID
    ) -> String {
        "\(videoID.uuidString)-\(Int(containerSize.width.rounded()))-\(Int(containerSize.height.rounded()))-\(Int(rotation))"
    }

    private func syncVideoLayout(for containerSize: CGSize) {
        guard let video = editorViewModel.currentVideo else { return }

        let size = editorViewModel.resolvedPlayerDisplaySize(
            for: video,
            in: containerSize
        )

        guard size.width > 0, size.height > 0 else { return }

        guard editorViewModel.currentVideo?.id == video.id else { return }

        editorViewModel.updateCurrentVideoLayout(
            to: size,
            textEditor: textEditor
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
    private let textEditor: TextEditorViewModel

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
        recorderManager: AudioRecorderManager,
        textEditor: TextEditorViewModel
    ) {
        self.editorViewModel = editorViewModel
        self.videoPlayer = videoPlayer
        self.recorderManager = recorderManager
        self.textEditor = textEditor
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
