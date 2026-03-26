//
//  RecorderButtonView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct RecorderButtonView: View {

    // MARK: - Private Properties

    private let video: Video
    private let recorderManager: AudioRecorderManager
    private let onRecorded: (Audio) -> Void
    private let onRecordTime: (Double) -> Void

    // MARK: - Body

    var body: some View {
        ZStack {
            switch recorderManager.controlState {
            case .empty:
                recordButton
            case .countdown:
                timerButton
            case .record:
                stopButton
            }
        }
        .opacity(video.hasRecordedAudio ? 0 : 1)
        .disabled(video.hasRecordedAudio)
        .onChange(of: recorderManager.finishedAudio) { _, newValue in
            guard let newValue else { return }
            onRecorded(newValue)
        }
        .onChange(of: recorderManager.currentRecordTime) { _, newValue in
            if newValue > 0 {
                onRecordTime(newValue)
            }
        }
    }

    // MARK: - Initializer

    init(
        _ video: Video,
        recorderManager: AudioRecorderManager,
        onRecorded: @escaping (Audio) -> Void,
        onRecordTime: @escaping (Double) -> Void
    ) {
        self.video = video
        self.recorderManager = recorderManager
        self.onRecorded = onRecorded
        self.onRecordTime = onRecordTime
    }

}

extension RecorderButtonView {

    // MARK: - Private Properties

    private var recordButton: some View {
        Button {
            recorderManager.startRecordingFlow(recordMaxTime: video.totalDuration)
        } label: {
            Image(systemName: "mic.fill")
                .font(.headline.weight(.semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(Theme.primary)
                .circleControl(prominent: true, tint: Theme.accent)
        }
        .buttonStyle(.plain)
    }

    private var timerButton: some View {
        Button {
            recorderManager.cancelRecordingFlow()
        } label: {
            Text("\(recorderManager.countdownRemaining)")
                .font(.subheadline.bold())
                .frame(width: 44, height: 44)
                .circleControl(prominent: true, tint: Theme.secondary)
        }
        .buttonStyle(.plain)
    }

    private var stopButton: some View {
        Button {
            recorderManager.cancelRecordingFlow()
        } label: {
            Image(systemName: "stop.fill")
                .font(.headline.weight(.semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(Theme.primary)
                .circleControl(prominent: true, tint: Theme.destructive)
        }
        .buttonStyle(.plain)
    }

}

#Preview {
    RecorderButtonView(
        Video.mock, recorderManager: AudioRecorderManager(), onRecorded: { _ in },
        onRecordTime: { _ in }
    )
    .padding()
    .preferredColorScheme(.dark)
}
