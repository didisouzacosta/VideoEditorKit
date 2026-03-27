//
//  AudioRecorderManager.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AudioRecorderManager: NSObject {

    // MARK: - Public Properties

    private(set) var recordState: AudioRecordEnum = .empty
    private(set) var finishedAudio: Audio?
    private(set) var currentRecordTime: TimeInterval = 0
    private(set) var controlState: ControlState = .empty
    private(set) var countdownRemaining = 3

    // MARK: - Private Properties

    @ObservationIgnored
    private var audioRecorder: AVAudioRecorder?

    @ObservationIgnored
    private var countdownTask: Task<Void, Never>?

    @ObservationIgnored
    private var recordingProgressTask: Task<Void, Never>?

    @ObservationIgnored
    private let clock = ContinuousClock()

    // MARK: - Initializer

    override init() {
        super.init()
    }

    // MARK: - Public Methods

    static func makeRecordingURL() -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cachesDirectory.appendingPathComponent("video-record-\(UUID().uuidString).m4a")
    }

    static func cancellationAction(for controlState: ControlState) -> FlowCancellationAction {
        switch controlState {
        case .empty:
            .none
        case .countdown:
            .resetCountdown
        case .record:
            .discardRecording
        }
    }

    func startRecordingFlow(recordMaxTime: Double) {
        stopCountdown()
        stopRecordingProgress()
        countdownRemaining = 3
        controlState = .countdown

        countdownTask = Task { [weak self] in
            guard let self else { return }

            for remaining in stride(from: 2, through: 1, by: -1) {
                do {
                    try await clock.sleep(for: .seconds(1))
                } catch {
                    return
                }

                guard !Task.isCancelled else { return }
                countdownRemaining = remaining
            }

            do {
                try await clock.sleep(for: .seconds(1))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            stopCountdown()
            startRecording(recordMaxTime: recordMaxTime)
        }
    }

    func cancelRecordingFlow() {
        switch Self.cancellationAction(for: controlState) {
        case .none:
            break
        case .resetCountdown:
            stopCountdown()
            controlState = .empty
        case .discardRecording:
            cancel()
        }
    }

    func startRecording(recordMaxTime: Double = 10) {
        AVAudioSession.sharedInstance().configureRecordAudioSessionCategory()
        stopCountdown()
        stopRecordingProgress()

        let audioURL = Self.makeRecordingURL()
        FileManager.default.removeIfExists(for: audioURL)
        finishedAudio = nil
        currentRecordTime = 0

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            let recorder = try AVAudioRecorder(url: audioURL, settings: settings)
            recorder.delegate = self
            audioRecorder = recorder
            recorder.prepareToRecord()
            recorder.record(forDuration: recordMaxTime)
            recordState = .recording
            controlState = .record
            startRecordingProgress()
        } catch {
            recordState = .error
            controlState = .empty
            assertionFailure("Failed to set up audio recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard let audioRecorder else { return }

        let duration = audioRecorder.currentTime
        audioRecorder.delegate = nil
        audioRecorder.stop()
        finishRecording(at: audioRecorder.url, duration: duration)
    }

    func cancel() {
        guard let audioRecorder else { return }

        audioRecorder.delegate = nil
        audioRecorder.stop()
        discardRecording(at: audioRecorder.url)
    }

    // MARK: - Private Methods

    private func startRecordingProgress() {
        recordingProgressTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard let audioRecorder else { return }

                currentRecordTime = audioRecorder.currentTime

                if !audioRecorder.isRecording {
                    return
                }

                do {
                    try await clock.sleep(for: .milliseconds(200))
                } catch {
                    return
                }
            }
        }
    }

    private func stopRecordingProgress() {
        recordingProgressTask?.cancel()
        recordingProgressTask = nil
        currentRecordTime = 0
    }

    private func finishRecording(
        at url: URL,
        duration: TimeInterval
    ) {
        recordState = .empty
        controlState = .empty
        finishedAudio = .init(url: url, duration: duration)
        audioRecorder = nil
        stopRecordingProgress()
    }

    private func discardRecording(at url: URL) {
        recordState = .empty
        controlState = .empty
        finishedAudio = nil
        audioRecorder = nil
        stopRecordingProgress()
        FileManager.default.removeIfExists(for: url)
    }

    private func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownRemaining = 3
    }

}

extension AudioRecorderManager {

    enum AudioRecordEnum: Int {
        case recording, empty, error
    }

    enum ControlState: Int {
        case empty, countdown, record
    }

    enum FlowCancellationAction: Equatable {
        case none
        case resetCountdown
        case discardRecording
    }

}

extension AudioRecorderManager: AVAudioRecorderDelegate {

    // MARK: - Public Methods

    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            if flag {
                finishRecording(at: recorder.url, duration: recorder.currentTime)
            } else {
                recordState = .error
                controlState = .empty
                finishedAudio = nil
                audioRecorder = nil
                stopRecordingProgress()
                FileManager.default.removeIfExists(for: recorder.url)
            }
        }
    }

}
