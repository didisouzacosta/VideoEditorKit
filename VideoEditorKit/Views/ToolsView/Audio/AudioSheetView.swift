//
//  AudioSheetView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@MainActor
struct AudioSheetView: View {

    // MARK: - States

    @State private var videoVolume: Float = 1.0
    @State private var audioVolume: Float = 1.0

    // MARK: - Public Properties

    private let videoPlayer: VideoPlayerManager
    private let editorVM: EditorViewModel
    private var value: Binding<Float> {
        editorVM.isSelectVideo ? $videoVolume : $audioVolume
    }

    // MARK: - Body

    var body: some View {
        HStack {
            Image(systemName: value.wrappedValue > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
            Slider(value: value, in: 0...1) { change in
                onChange()
            }
            .tint(Theme.accent)
            Text("\(Int(value.wrappedValue * 100))")
        }
        .font(.caption)
        .onAppear {
            setValue()
        }
    }

    // MARK: - Initializer

    init(videoPlayer: VideoPlayerManager, editorVM: EditorViewModel) {
        self.videoPlayer = videoPlayer
        self.editorVM = editorVM
    }

}

extension AudioSheetView {

    // MARK: - Private Methods

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
