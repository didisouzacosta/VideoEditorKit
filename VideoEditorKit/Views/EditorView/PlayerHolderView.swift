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

    // MARK: - Bindings

    @Binding private var isFullScreen: Bool

    // MARK: - Public Properties

    private let editorVM: EditorViewModel
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
        isFullScreen: Binding<Bool>,
        editorVM: EditorViewModel,
        videoPlayer: VideoPlayerManager,
        textEditor: TextEditorViewModel
    ) {
        self._isFullScreen = isFullScreen
        self.editorVM = editorVM
        self.videoPlayer = videoPlayer
        self.textEditor = textEditor
    }

}

extension PlayerHolderView {

    // MARK: - Private Properties

    private var playerCropView: some View {
        Group {
            if let video = editorVM.currentVideo {
                GeometryReader { proxy in
                    let displaySize = resolvedDisplaySize(for: video, in: proxy.size)

                    ZStack {
                        CropView(
                            originalSize: displaySize,
                            rotation: editorVM.currentVideo?.rotation,
                            isMirror: editorVM.currentVideo?.isMirror ?? false,
                            isActiveCrop: editorVM.selectedTools == .crop
                        ) {
                            ZStack {
                                editorVM.frames.frameColor
                                ZStack {
                                    PlayerView(player: videoPlayer.videoPlayer)
                                    TextOverlayView(
                                        currentTime: videoPlayer.currentTime, viewModel: textEditor,
                                        disabledMagnification: isFullScreen
                                    )
                                    .disabled(isFullScreen)
                                }
                                .scaleEffect(editorVM.frames.scale)
                            }
                        }
                        .frame(width: displaySize.width, height: displaySize.height)
                        .clipShape(.rect(cornerRadius: 24))
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

            timelineLabel
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
        guard let video = editorVM.currentVideo else { return }
        let size = resolvedDisplaySize(for: video, in: containerSize)
        guard size.width > 0, size.height > 0 else { return }

        guard editorVM.currentVideo?.id == video.id else { return }

        if editorVM.currentVideo?.frameSize != size {
            editorVM.currentVideo?.frameSize = size
        }

        if editorVM.currentVideo?.geometrySize != size {
            editorVM.currentVideo?.geometrySize = size
        }
    }

}

extension PlayerHolderView {

    // MARK: - Private Properties

    @ViewBuilder
    private var timelineLabel: some View {
        if let video = editorVM.currentVideo {
            let displayTime = videoPlayer.currentTime.clamped(to: video.rangeDuration)
            HStack {
                Text(
                    "\((displayTime - video.rangeDuration.lowerBound).formatterTimeString()) / \(Int(video.totalDuration).secondsToTime())"
                )
            }
            .font(.caption2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .capsuleControl()
            .padding()
        }
    }

}

@MainActor
struct PlayerControl: View {

    // MARK: - Bindables

    @Bindable private var editorVM: EditorViewModel
    @Bindable private var videoPlayer: VideoPlayerManager

    // MARK: - Bindings

    @Binding private var isFullScreen: Bool

    // MARK: - Public Properties

    private let recorderManager: AudioRecorderManager
    private let textEditor: TextEditorViewModel

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        VStack(spacing: 32) {
            playSection

            if editorVM.currentVideo != nil {
                timeLineControlSection
            }
        }
    }

    // MARK: - Initializer

    init(
        editorVM: EditorViewModel,
        videoPlayer: VideoPlayerManager,
        isFullScreen: Binding<Bool>,
        recorderManager: AudioRecorderManager,
        textEditor: TextEditorViewModel
    ) {
        self.editorVM = editorVM
        self.videoPlayer = videoPlayer
        self._isFullScreen = isFullScreen
        self.recorderManager = recorderManager
        self.textEditor = textEditor
    }

    // MARK: - Private Properties

    @ViewBuilder
    private var timeLineControlSection: some View {
        if let video = editorVM.currentVideo {
            trimSection(video)
        }
    }

    private var playSection: some View {
        Button {
            if let video = editorVM.currentVideo {
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
            currentTime: $videoPlayer.currentTime,
            video: $editorVM.currentVideo,
            isChangeState: video.isAppliedTool(for: .cut)
        ) { newRange in
            videoPlayer.pause()
            videoPlayer.updatePlaybackRange(newRange)
            editorVM.setCut()
        } onRequestThumbnails: { size in
            editorVM.refreshThumbnailsIfNeeded(containerSize: size)
        } onPlaybackScrubStarted: { range in
            videoPlayer.beginScrubbing(in: range)
        } onPlaybackScrubChanged: { time, range in
            videoPlayer.scrub(
                to: time,
                in: editorVM.currentVideo?.rangeDuration ?? range
            )
        } onPlaybackScrubEnded: { time, range in
            videoPlayer.endScrubbing(
                at: time,
                in: editorVM.currentVideo?.rangeDuration ?? range
            )
        }
        .padding(.horizontal)
    }

}

#Preview {
    MainEditorView()
}
