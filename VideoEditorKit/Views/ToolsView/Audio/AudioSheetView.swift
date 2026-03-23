//
//  AudioSheetView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@MainActor
struct AudioSheetView: View {
    @State private var videoVolume: Float = 1.0
    @State private var audioVolume: Float = 1.0
    let videoPlayer: VideoPlayerManager
    let editorVM: EditorViewModel

    var value: Binding<Float> {
        editorVM.isSelectVideo ? $videoVolume : $audioVolume
    }

    var body: some View {
        HStack {
            Image(systemName: value.wrappedValue > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
            Slider(value: value, in: 0...1) { change in
                onChange()
            }
            .tint(IOS26Theme.accent)
            Text("\(Int(value.wrappedValue * 100))")
        }
        .font(.caption)
        .foregroundStyle(IOS26Theme.primaryText)
        .onAppear {
            setValue()
        }
    }
}

extension AudioSheetView {

    private func setValue() {
        guard let video = editorVM.currentVideo else { return }
        if editorVM.isSelectVideo {
            videoVolume = video.volume
        } else if let audio = video.audio {
            audioVolume = audio.volume
        }
    }

    private func onChange() {
        if editorVM.isSelectVideo {
            editorVM.currentVideo?.setVolume(videoVolume)
        } else {
            editorVM.currentVideo?.audio?.setVolume(audioVolume)
        }
        videoPlayer.setVolume(editorVM.isSelectVideo, value: value.wrappedValue)
    }
}

#Preview {
    AudioSheetView(videoPlayer: VideoPlayerManager(), editorVM: EditorViewModel())
        .padding()
}
