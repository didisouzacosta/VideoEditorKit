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
    var scale: CGFloat {
        isFullScreen ? 1.4 : 1
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                switch videoPlayer.loadState {
                case .loading:
                    ProgressView()
                        .tint(.white)
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
        .foregroundStyle(.white)
        .padding(14)
        .ios26Card(cornerRadius: 34, prominent: true, tint: IOS26Theme.accentSecondary)
    }
}

extension PlayerHolderView {
    private func statusView(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .ios26CapsuleControl(tint: IOS26Theme.accentSecondary)
    }

    private var playerCropView: some View {
        Group {
            if let video = editorVM.currentVideo {
                GeometryReader { proxy in
                    CropView(
                        originalSize: .init(
                            width: video.frameSize.width * scale, height: video.frameSize.height * scale),
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
                                .scaleEffect(scale)
                                .disabled(isFullScreen)
                            }
                            .scaleEffect(editorVM.frames.scale)
                        }
                    }
                    .allFrame()
                    .onAppear {
                        Task { @MainActor in
                            guard let size = await editorVM.currentVideo?.asset.adjustVideoSize(to: proxy.size)
                            else { return }
                            editorVM.currentVideo?.frameSize = size
                            editorVM.currentVideo?.geometrySize = proxy.size
                        }
                    }
                }
            }
            timelineLabel
        }
    }
}

extension PlayerHolderView {

    @ViewBuilder
    private var timelineLabel: some View {
        if let video = editorVM.currentVideo {
            HStack {
                Text((videoPlayer.currentTime - video.rangeDuration.lowerBound).formatterTimeString())
                    + Text(" / ") + Text(Int(video.totalDuration).secondsToTime())
            }
            .font(.caption2)
            .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
