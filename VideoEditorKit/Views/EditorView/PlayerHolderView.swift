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
    @Binding var isFullScreen: Bool
    let editorVM: EditorViewModel
    let videoPlayer: VideoPlayerManager
    let textEditor: TextEditorViewModel

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                switch videoPlayer.loadState {
                case .loading:
                    ProgressView()
                        .tint(IOS26Theme.accent)
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
        .foregroundStyle(IOS26Theme.primaryText)
        .padding(14)
        .ios26Card(cornerRadius: 34, prominent: true, tint: IOS26Theme.accentSecondary)
    }
}

extension PlayerHolderView {
    private func statusView(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(IOS26Theme.primaryText)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .ios26CapsuleControl(tint: IOS26Theme.accentSecondary)
    }

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
                        await updateVideoLayout(for: proxy.size)
                    }
                }
            }
            timelineLabel
        }
    }

    private func resolvedDisplaySize(for video: Video, in containerSize: CGSize) -> CGSize {
        let fallbackSize = CGSize(
            width: max(containerSize.width, 1),
            height: max(containerSize.height, 1)
        )

        if video.frameSize.width > 0, video.frameSize.height > 0 {
            return fittedSize(video.frameSize, in: fallbackSize)
        }

        return fallbackSize
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

    private func updateVideoLayout(for containerSize: CGSize) async {
        guard let video = editorVM.currentVideo else { return }
        guard
            let size = await video.asset.adjustVideoSize(
                to: containerSize,
                rotationAngle: video.rotation
            )
        else { return }

        guard editorVM.currentVideo?.id == video.id else { return }
        editorVM.currentVideo?.frameSize = size
        editorVM.currentVideo?.geometrySize = size
    }
}

extension PlayerHolderView {

    @ViewBuilder
    private var timelineLabel: some View {
        if let video = editorVM.currentVideo {
            HStack {
                Text(
                    "\((videoPlayer.currentTime - video.rangeDuration.lowerBound).formatterTimeString()) / \(Int(video.totalDuration).secondsToTime())"
                )
            }
            .font(.caption2)
            .foregroundStyle(IOS26Theme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .ios26CapsuleControl(tint: IOS26Theme.accentSecondary)
            .padding()
        }
    }
}

@MainActor
struct PlayerControl: View {
    @Binding var isFullScreen: Bool
    let recorderManager: AudioRecorderManager
    @Bindable var editorVM: EditorViewModel
    @Bindable var videoPlayer: VideoPlayerManager
    let textEditor: TextEditorViewModel
    var body: some View {
        VStack(spacing: 14) {
            playSection
            if editorVM.currentVideo != nil {
                timeLineControlSection
                    .padding(12)
                    .ios26Card(cornerRadius: 28, tint: IOS26Theme.accentSecondary)
            }
        }
    }

    @ViewBuilder
    private var timeLineControlSection: some View {
        if let video = editorVM.currentVideo {
            TimeLineView(
                recorderManager: recorderManager,
                currentTime: $videoPlayer.currentTime,
                isSelectedTrack: $editorVM.isSelectVideo,
                viewState: editorVM.selectedTools?.timeState ?? .empty,
                video: video, textInterval: textEditor.selectedTextBox?.timeRange
            ) {
                videoPlayer.scrubState = .scrubEnded(videoPlayer.currentTime)
            } onChangeTextTime: { textTime in
                textEditor.setTime(textTime)
            } onSetAudio: { audio in
                editorVM.setAudio(audio)
                videoPlayer.setAudio(audio.url)
            }
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
                .foregroundStyle(IOS26Theme.primaryText)
                .ios26CircleControl(prominent: true, tint: IOS26Theme.accent)
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(IOS26Theme.primaryText)
                .ios26CircleControl()
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    MainEditorView()
        .preferredColorScheme(.dark)
}
