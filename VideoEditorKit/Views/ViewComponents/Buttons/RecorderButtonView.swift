//
//  RecorderButtonView.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import SwiftUI

struct RecorderButtonView: View {

    // MARK: - States

    @State private var timeRemaining = 3
    @State private var timer: Timer? = nil
    @State private var state: StateEnum = .empty

    // MARK: - Private Properties

    private let video: Video
    private let recorderManager: AudioRecorderManager
    private let onRecorded: (Audio) -> Void
    private let onRecordTime: (Double) -> Void

    // MARK: - Body

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

    // MARK: - Private Properties

    private var isSetAudio: Bool {
        video.audio != nil
    }

}

extension RecorderButtonView {

    // MARK: - Public Properties

    enum StateEnum: Int {
        case empty, timer, record
    }

    // MARK: - Private Properties

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

    // MARK: - Private Methods

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
        Video.mock, recorderManager: AudioRecorderManager(), onRecorded: { _ in },
        onRecordTime: { _ in }
    )
    .padding()
    .preferredColorScheme(.dark)
}
