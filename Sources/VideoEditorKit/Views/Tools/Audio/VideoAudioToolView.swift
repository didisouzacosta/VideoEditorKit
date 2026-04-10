//
//  VideoAudioToolView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct AudioToolDraft: Equatable {

    // MARK: - Public Properties

    var selectedTrack: VideoEditingConfiguration.SelectedTrack = .video
    var videoVolume: Float = 1
    var recordedVolume: Float = 1

    var selectedTrackVolume: Float {
        get {
            switch selectedTrack {
            case .video:
                videoVolume
            case .recorded:
                recordedVolume
            }
        }
        set {
            switch selectedTrack {
            case .video:
                videoVolume = newValue
            case .recorded:
                recordedVolume = newValue
            }
        }
    }

    // MARK: - Initializer

    init(
        selectedTrack: VideoEditingConfiguration.SelectedTrack = .video,
        videoVolume: Float = 1,
        recordedVolume: Float = 1
    ) {
        self.selectedTrack = selectedTrack
        self.videoVolume = videoVolume
        self.recordedVolume = recordedVolume
    }

    init(
        video: Video?,
        selectedTrack: VideoEditingConfiguration.SelectedTrack
    ) {
        self.init(
            selectedTrack: selectedTrack,
            videoVolume: video?.volume ?? 1,
            recordedVolume: video?.audio?.volume ?? 1
        )
    }

}

struct VideoAudioToolView: View {

    // MARK: - Bindings

    @Binding private var draft: AudioToolDraft

    // MARK: - Public Properties

    private let hasRecordedAudioTrack: Bool

    // MARK: - Body

    var body: some View {
        let currentVolume = draft.selectedTrackVolume

        VStack(alignment: .leading, spacing: 16) {
            if hasRecordedAudioTrack {
                Picker(VideoEditorStrings.audioTrack, selection: $draft.selectedTrack) {
                    ForEach(VideoEditingConfiguration.SelectedTrack.allCases) { track in
                        Text(track.title).tag(track)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Image(systemName: currentVolume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                Slider(value: $draft.selectedTrackVolume, in: 0...1) { _ in }
                    .tint(Theme.accent)
                Text("\(Int(currentVolume * 100))")
            }
            .font(.caption)
        }
        .safeAreaPadding()
    }

    // MARK: - Initializer

    init(
        draft: Binding<AudioToolDraft>,
        hasRecordedAudioTrack: Bool
    ) {
        _draft = draft
        self.hasRecordedAudioTrack = hasRecordedAudioTrack
    }

}

#Preview {
    VideoAudioToolView(
        draft: .constant(
            .init(
                selectedTrack: .recorded,
                videoVolume: 1,
                recordedVolume: 0.35
            )
        ),
        hasRecordedAudioTrack: true
    )
}
