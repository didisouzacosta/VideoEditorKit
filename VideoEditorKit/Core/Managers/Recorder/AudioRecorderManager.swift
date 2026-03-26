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
final class AudioRecorderManager {

    // MARK: - Public Properties

    private(set) var recordState: AudioRecordEnum = .empty
    private(set) var finishedAudio: Audio?
    private(set) var currentRecordTime: TimeInterval = 0

    enum AudioRecordEnum: Int {
        case recording, empty, error
    }

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    // MARK: - Public Methods

    func startRecording(recordMaxTime: Double = 10) {
        AVAudioSession.sharedInstance().configureRecordAudioSessionCategory()

        let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let audioURL = path.appendingPathComponent("video-record.m4a")
        FileManager.default.removeIfExists(for: audioURL)
        finishedAudio = nil
        resetTimer()

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            let recorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder = recorder
            recorder.prepareToRecord()
            recorder.record()
            recordState = .recording
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.currentRecordTime += 0.2
                    if self.currentRecordTime >= recordMaxTime {
                        self.stopRecording()
                    }
                }
            }
        } catch {
            recordState = .error
            assertionFailure("Failed to set up audio recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard let audioRecorder else { return }
        audioRecorder.stop()
        recordState = .empty
        finishedAudio = .init(url: audioRecorder.url, duration: currentRecordTime)
        resetTimer()
    }

    func cancel() {
        guard let audioRecorder else { return }
        audioRecorder.stop()
        recordState = .empty
        resetTimer()
        FileManager.default.removeIfExists(for: audioRecorder.url)
    }

    // MARK: - Private Methods

    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        currentRecordTime = 0
    }

}
