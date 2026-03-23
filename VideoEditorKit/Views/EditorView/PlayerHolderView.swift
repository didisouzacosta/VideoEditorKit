//
//  PlayerHolderView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI
import Observation

@MainActor
struct PlayerHolderView: View{
    @Binding var isFullScreen: Bool
    let editorVM: EditorViewModel
    let videoPlayer: VideoPlayerManager
    let textEditor: TextEditorViewModel
    var scale: CGFloat{
        isFullScreen ? 1.4 : 1
    }

    var body: some View{
        VStack(spacing: 6) {
            ZStack(alignment: .bottom){
                switch videoPlayer.loadState{
                case .loading:
                    ProgressView()
                case .unknown:
                    Text("Add new video")
                case .failed:
                    Text("Failed to open video")
                case .loaded:
                    playerCropView
                }
            }
            .allFrame()
        }
    }
}

extension PlayerHolderView{

    private var playerCropView: some View{
        Group{
            if let video = editorVM.currentVideo{
                GeometryReader { proxy in
                    CropView(
                        originalSize: .init(width: video.frameSize.width * scale, height: video.frameSize.height * scale),
                        rotation: editorVM.currentVideo?.rotation,
                        isMirror: editorVM.currentVideo?.isMirror ?? false,
                        isActiveCrop: editorVM.selectedTools == .crop) {
                            ZStack{
                                editorVM.frames.frameColor
                                ZStack{
                                    PlayerView(player: videoPlayer.videoPlayer)
                                    TextOverlayView(currentTime: videoPlayer.currentTime, viewModel: textEditor,  disabledMagnification: isFullScreen)
                                        .scaleEffect(scale)
                                        .disabled(isFullScreen)
                                }
                                .scaleEffect(editorVM.frames.scale)
                            }
                        }
                        .allFrame()
                        .onAppear{
                            Task { @MainActor in
                                guard let size = await editorVM.currentVideo?.asset.adjustVideoSize(to: proxy.size) else {return}
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

extension PlayerHolderView{
    
    @ViewBuilder
    private var timelineLabel: some View{
        if let video = editorVM.currentVideo{
            HStack{
                Text((videoPlayer.currentTime - video.rangeDuration.lowerBound)  .formatterTimeString()) +
                Text(" / ") +
                Text(Int(video.totalDuration).secondsToTime())
            }
            .font(.caption2)
            .foregroundStyle(.white)
            .frame(width: 80)
            .padding(5)
            .background(Color(.black).opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .padding()
        }
    }
}

@MainActor
struct PlayerControl: View{
    @Binding var isFullScreen: Bool
    let recorderManager: AudioRecorderManager
    @Bindable var editorVM: EditorViewModel
    @Bindable var videoPlayer: VideoPlayerManager
    let textEditor: TextEditorViewModel
    var body: some View{
        VStack(spacing: 6) {
            playSection
            timeLineControlSection
        }
    }
    
    
    @ViewBuilder
    private var timeLineControlSection: some View{
        if let video = editorVM.currentVideo{
            TimeLineView(
                recorderManager: recorderManager,
                currentTime: $videoPlayer.currentTime,
                isSelectedTrack: $editorVM.isSelectVideo,
                viewState: editorVM.selectedTools?.timeState ?? .empty,
                video: video, textInterval: textEditor.selectedTextBox?.timeRange) {
                    videoPlayer.scrubState = .scrubEnded(videoPlayer.currentTime)
                } onChangeTextTime: { textTime in
                    textEditor.setTime(textTime)
                } onSetAudio: { audio in
                    editorVM.setAudio(audio)
                    videoPlayer.setAudio(audio.url)
                }
        }
    }
    
    private var playSection: some View{
        
        Button {
            if let video = editorVM.currentVideo{
                videoPlayer.action(video)
            }
        } label: {
            Image(systemName: videoPlayer.isPlaying ? "pause.fill" : "play.fill")
                .imageScale(.medium)
        }
        .buttonStyle(.plain)
        .hCenter()
        .frame(height: 30)
        .overlay(alignment: .trailing) {
            Button {
                videoPlayer.pause()
                withAnimation {
                    isFullScreen.toggle()
                }
            } label: {
                Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
}

#Preview {
    MainEditorView(project: nil, selectedVideoURl: nil)
        .preferredColorScheme(.dark)
}
