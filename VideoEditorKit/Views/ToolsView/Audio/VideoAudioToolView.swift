//
//  VideoAudioToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@MainActor
struct VideoAudioToolView: View {

    // MARK: - Private Properties

    private let editorVM: EditorViewModel
    private let videoPlayer: VideoPlayerManager

    // MARK: - Body

    var body: some View {
        let currentVolume = editorVM.selectedTrackVolume()

        VStack(alignment: .leading, spacing: 16) {
            if editorVM.hasRecordedAudioTrack {
                Picker("Track", selection: editorVM.audioTrackSelectionBinding()) {
                    ForEach(EditorViewModel.AudioTrackSelection.allCases) { track in
                        Text(track.title).tag(track)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Image(systemName: currentVolume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                Slider(value: editorVM.selectedTrackVolumeBinding(videoPlayer: videoPlayer), in: 0...1) { _ in }
                    .tint(Theme.accent)
                Text("\(Int(currentVolume * 100))")
            }
            .font(.caption)
        }
    }

    // MARK: - Initializer

    init(_ videoPlayer: VideoPlayerManager, editorVM: EditorViewModel) {
        self.videoPlayer = videoPlayer
        self.editorVM = editorVM
    }

}

#Preview {
    VideoAudioToolView(VideoPlayerManager(), editorVM: EditorViewModel())
}
