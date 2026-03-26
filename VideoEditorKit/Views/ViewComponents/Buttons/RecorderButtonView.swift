//
//  RecorderButtonView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct RecorderButtonView: View {
    var video: Video
    var recorderManager: AudioRecorderManager
    @State private var timeRemaining = 3
    @State private var timer: Timer? = nil
    @State private var state: StateEnum = .empty
    let onRecorded: (Audio) -> Void
    let onRecordTime: (Double) -> Void

    private var isSetAudio: Bool {
        video.audio != nil
    }

    var body: some View {
        ZStack {
            switch state {
            case .empty:
                if isSetAudio {}
                recordButton
            case .timer:
                timerButton
            case .record:
                stopButton
            }
        }
        .opacity(isSetAudio ? 0 : 1)
        .disabled(isSetAudio)
        .onChange(of: recorderManager.finishedAudio) { _, newValue in
            guard let newValue else { return }
            onRecorded(newValue)
            state = .empty
        }
        .onChange(of: recorderManager.currentRecordTime) { _, newValue in
            if newValue > 0 {
                onRecordTime(newValue)
            }
        }
    }
}

extension RecorderButtonView {

    enum StateEnum: Int {
        case empty, timer, record
    }

    private var recordButton: some View {
        Button {
            state = .timer
            startTimer()
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
            state = .empty
            stopTimer()
        } label: {
            Text("\(timeRemaining)")
                .font(.subheadline.bold())
                .frame(width: 44, height: 44)
                .circleControl(prominent: true, tint: Theme.secondary)
        }
        .buttonStyle(.plain)
    }

    private var stopButton: some View {
        Button {
            state = .empty
            recorderManager.stopRecording()
        } label: {
            Image(systemName: "stop.fill")
                .font(.headline.weight(.semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(Theme.primary)
                .circleControl(prominent: true, tint: Theme.destructive)
        }
        .buttonStyle(.plain)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                timeRemaining -= 1
                if timeRemaining == 0 {
                    state = .record
                    stopTimer()
                    recorderManager.startRecording(recordMaxTime: video.totalDuration)
                }
            }
        }
    }

    private func stopTimer() {
        timeRemaining = 3
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    RecorderButtonView(
        video: Video.mock, recorderManager: AudioRecorderManager(), onRecorded: { _ in },
        onRecordTime: { _ in }
    )
    .padding()
    .preferredColorScheme(.dark)
}
