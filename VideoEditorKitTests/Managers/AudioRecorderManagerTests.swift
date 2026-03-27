import Foundation
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("AudioRecorderManagerTests")
struct AudioRecorderManagerTests {

    // MARK: - Public Methods

    @Test
    func initialStateStartsEmpty() {
        let manager = AudioRecorderManager()

        #expect(manager.recordState == .empty)
        #expect(manager.controlState == .empty)
        #expect(manager.finishedAudio == nil)
        #expect(manager.currentRecordTime == 0)
        #expect(manager.countdownRemaining == 3)
    }

    @Test
    func startRecordingFlowStartsTheCountdownState() {
        let manager = AudioRecorderManager()

        manager.startRecordingFlow(recordMaxTime: 5)

        #expect(manager.controlState == .countdown)
        #expect(manager.countdownRemaining == 3)
        #expect(manager.recordState == .empty)
    }

    @Test
    func cancelRecordingFlowDuringCountdownResetsTheManager() {
        let manager = AudioRecorderManager()
        manager.startRecordingFlow(recordMaxTime: 5)

        manager.cancelRecordingFlow()

        #expect(manager.controlState == .empty)
        #expect(manager.countdownRemaining == 3)
        #expect(manager.recordState == .empty)
    }

    @Test
    func stopRecordingWithoutAnActiveRecorderLeavesStateUnchanged() {
        let manager = AudioRecorderManager()

        manager.stopRecording()

        #expect(manager.recordState == .empty)
        #expect(manager.controlState == .empty)
        #expect(manager.finishedAudio == nil)
    }

    @Test
    func cancelWithoutAnActiveRecorderLeavesStateUnchanged() {
        let manager = AudioRecorderManager()

        manager.cancel()

        #expect(manager.recordState == .empty)
        #expect(manager.controlState == .empty)
        #expect(manager.finishedAudio == nil)
        #expect(manager.currentRecordTime == 0)
    }

    @Test
    func recordingURLFactoryCreatesUniqueAudioFilesInCachesDirectory() {
        let firstURL = AudioRecorderManager.makeRecordingURL()
        let secondURL = AudioRecorderManager.makeRecordingURL()
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]

        #expect(firstURL != secondURL)
        #expect(firstURL.pathExtension == "m4a")
        #expect(secondURL.pathExtension == "m4a")
        #expect(firstURL.deletingLastPathComponent() == cachesDirectory)
        #expect(secondURL.deletingLastPathComponent() == cachesDirectory)
    }

}
