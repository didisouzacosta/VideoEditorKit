//
//  AudioButtonView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import SwiftUI

struct AudioButtonView: View {

    // MARK: - Bindings

    @Binding private var isSelectedTrack: Bool

    // MARK: - States

    @State private var audioSamples = [Audio.AudioSample]()

    // MARK: - Public Properties

    private let video: Video
    private let recorderManager: AudioRecorderManager

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.outline.opacity(0.25))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.outline, lineWidth: 1)
                    }

                if let audio = video.audio {
                    audioButton(proxy, audio)
                } else if recorderManager.recordState == .recording {
                    recordRectangle(proxy)
                }
            }
            .clipShape(.rect(cornerRadius: 14))
        }
        .frame(height: 44)
    }

    // MARK: - Initializer

    init(
        isSelectedTrack: Binding<Bool>,
        video: Video,
        recorderManager: AudioRecorderManager
    ) {
        self._isSelectedTrack = isSelectedTrack
        self.video = video
        self.recorderManager = recorderManager
    }

}

extension AudioButtonView {

    // MARK: - Private Methods

    private func recordRectangle(_ proxy: GeometryProxy) -> some View {
        let width = getWidthFromDuration(
            totalWidth: proxy.size.width,
            currentDuration: recorderManager.currentRecordTime,
            totalDuration: video.totalDuration
        )

        return RoundedRectangle(cornerRadius: 8)
            .fill(Theme.accent.opacity(0.65))
            .frame(width: width)
            .hLeading()
            .animation(.easeIn, value: recorderManager.currentRecordTime)
    }

    private func audioButton(_ proxy: GeometryProxy, _ audio: Audio) -> some View {
        let width = getWidthFromDuration(
            totalWidth: proxy.size.width,
            currentDuration: audio.duration,
            totalDuration: video.totalDuration
        )

        return RoundedRectangle(cornerRadius: 8)
            .fill(Theme.accent.opacity(isSelectedTrack ? 0.48 : 0.70))
            .overlay {
                ZStack {
                    if !isSelectedTrack {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Theme.primary, lineWidth: 2)
                    }

                    HStack(spacing: 1) {
                        ForEach(audioSamples) { sample in
                            Capsule()
                                .fill(Theme.primary)
                                .frame(width: 2, height: sample.size)
                        }
                    }
                }
            }
            .frame(width: width)
            .hLeading()
            .onAppear {
                audioSamples = audio.createSamples(width)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isSelectedTrack.toggle()
                }
            }
    }

    private func getWidthFromDuration(
        totalWidth: CGFloat,
        currentDuration: Double,
        totalDuration: Double
    ) -> CGFloat {
        (totalWidth / totalDuration) * currentDuration
    }

}

#Preview {
    AudioButtonView(
        isSelectedTrack: .constant(false),
        video: Video.mock,
        recorderManager: AudioRecorderManager()
    )
    .frame(height: 40)
    .padding()
}
