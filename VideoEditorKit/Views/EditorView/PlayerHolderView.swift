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

    // MARK: - Bindings

    @Binding private var isFullScreen: Bool

    // MARK: - Private Properties

    private let editorViewModel: EditorViewModel
    private let videoPlayer: VideoPlayerManager
    private let textEditor: TextEditorViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 6) {
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
        _ isFullScreen: Binding<Bool>,
        editorVM: EditorViewModel,
        videoPlayer: VideoPlayerManager,
        textEditor: TextEditorViewModel
    ) {
        _isFullScreen = isFullScreen

        self.editorViewModel = editorVM
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
                    let displaySize = resolvedDisplaySize(for: video, in: proxy.size)

                    ZStack {
                        CropView(
                            displaySize,
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
                                        viewModel: textEditor,
                                        disabledMagnification: isFullScreen
                                    )
                                    .disabled(isFullScreen)
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
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .capsuleControl()
    }

    private func resolvedDisplaySize(for video: Video, in containerSize: CGSize) -> CGSize {
        let fallbackSize = CGSize(
            width: max(containerSize.width, 1),
            height: max(containerSize.height, 1)
        )

        let baseSize = rotatedBaseSize(for: video)
        guard baseSize.width > 0, baseSize.height > 0 else { return fallbackSize }

        return fittedSize(baseSize, in: fallbackSize)
    }

    private func fittedSize(_ size: CGSize, in bounds: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return bounds }
        guard bounds.width > 0, bounds.height > 0 else { return size }

        let widthScale = bounds.width / size.width
        let heightScale = bounds.height / size.height
        let scale = min(widthScale, heightScale, 1)

        return CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    private func playerLayoutID(for containerSize: CGSize, rotation: Double, videoID: UUID) -> String {
        "\(videoID.uuidString)-\(Int(containerSize.width.rounded()))-\(Int(containerSize.height.rounded()))-\(Int(rotation))"
    }

    private func rotatedBaseSize(for video: Video) -> CGSize {
        let baseSize: CGSize
        if video.presentationSize.width > 0, video.presentationSize.height > 0 {
            baseSize = video.presentationSize
        } else {
            baseSize = video.frameSize
        }

        guard baseSize.width > 0, baseSize.height > 0 else { return .zero }

        let normalizedRotation = abs(Int(video.rotation)) % 180
        if normalizedRotation == 90 {
            return CGSize(width: baseSize.height, height: baseSize.width)
        }

        return baseSize
    }

    private func syncVideoLayout(for containerSize: CGSize) {
        guard let video = editorViewModel.currentVideo else { return }
        let size = resolvedDisplaySize(for: video, in: containerSize)
        guard size.width > 0, size.height > 0 else { return }

        guard editorViewModel.currentVideo?.id == video.id else { return }

        if editorViewModel.currentVideo?.frameSize != size {
            editorViewModel.currentVideo?.frameSize = size
        }

        if editorViewModel.currentVideo?.geometrySize != size {
            editorViewModel.currentVideo?.geometrySize = size
        }
    }

}

@MainActor
struct PlayerControl: View {

    // MARK: - Environments

    @Environment(\.displayScale) private var displayScale

    // MARK: - Bindings

    @Binding private var isFullScreen: Bool

    // MARK: - Private Properties

    private let editorViewModel: EditorViewModel
    private let videoPlayer: VideoPlayerManager
    private let recorderManager: AudioRecorderManager
    private let textEditor: TextEditorViewModel

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        VStack(spacing: 32) {
            playSection

            if editorViewModel.hasCurrentVideo {
                timeLineControlSection
            }
        }
    }

    // MARK: - Initializer

    init(
        _ isFullScreen: Binding<Bool>,
        editorViewModel: EditorViewModel,
        videoPlayer: VideoPlayerManager,
        recorderManager: AudioRecorderManager,
        textEditor: TextEditorViewModel
    ) {
        _isFullScreen = isFullScreen

        self.editorViewModel = editorViewModel
        self.videoPlayer = videoPlayer
        self.recorderManager = recorderManager
        self.textEditor = textEditor
    }

    // MARK: - Private Properties

    @ViewBuilder
    private var timeLineControlSection: some View {
        if let video = editorViewModel.currentVideo {
            trimSection(video)
        }
    }

    private var playSection: some View {
        Button {
            if let video = editorViewModel.currentVideo {
                videoPlayer.action(video)
            }
        } label: {
            Image(systemName: videoPlayer.isPlaying ? "pause.fill" : "play.fill")
                .font(.title2.weight(.semibold))
                .frame(width: 72, height: 72)
                .circleControl()
        }
        .hCenter()
        .overlay(alignment: .trailing) {
            Button {
                videoPlayer.pause()
                withAnimation {
                    isFullScreen.toggle()
                }
            } label: {
                Image(
                    systemName: isFullScreen
                        ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                )
                .font(.headline.weight(.semibold))
                .frame(width: 46, height: 46)
                .circleControl()
            }
        }
    }

    // MARK: - Private Methods

    private func trimSection(_ video: Video) -> some View {
        ThumbnailsSliderView(
            videoPlayer.currentTimeBinding(),
            video: .init(
                get: { editorViewModel.currentVideo },
                set: { editorViewModel.currentVideo = $0 }
            ),
            isChangeState: video.isAppliedTool(for: .cut)
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
                in: editorViewModel.currentVideo?.rangeDuration ?? range
            )
        } onPlaybackScrubEnded: { time, range in
            videoPlayer.endScrubbing(
                at: time,
                in: editorViewModel.currentVideo?.rangeDuration ?? range
            )
        }
        .padding(.horizontal)
    }

}

#Preview {
    MainEditorView()
}
