//
//  AudioSheetView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

@MainActor
struct AudioSheetView: View {

    // MARK: - Private Properties

    private let editorVM: EditorViewModel
    private let videoPlayer: VideoPlayerManager

    // MARK: - Body

    var body: some View {
        let currentVolume = editorVM.selectedTrackVolume()

        HStack {
            Image(systemName: currentVolume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
            Slider(value: editorVM.selectedTrackVolumeBinding(videoPlayer: videoPlayer), in: 0...1) { _ in }
                .tint(Theme.accent)
            Text("\(Int(currentVolume * 100))")
        }
        .font(.caption)
    }

    // MARK: - Initializer

    init(_ videoPlayer: VideoPlayerManager, editorVM: EditorViewModel) {
        self.videoPlayer = videoPlayer
        self.editorVM = editorVM
    }

}

#Preview {
    AudioSheetView(VideoPlayerManager(), editorVM: EditorViewModel())
        .padding()
}
