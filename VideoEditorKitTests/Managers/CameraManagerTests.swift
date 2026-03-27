import AVFoundation
import Foundation
import Testing

@testable import VideoEditorKit

@Suite("CameraManagerTests")
struct CameraManagerTests {

    // MARK: - Public Methods

    @Test
    func initialPublicStateMatchesCurrentDefaults() {
        let manager = CameraManager(autoConfigure: false)

        #expect(manager.finalURL == nil)
        #expect(manager.recordedDuration == 0)
        #expect(manager.cameraPosition == .back)
        #expect(manager.maxDuration == 100)
        #expect(manager.isRecording == false)
    }

    @Test
    func consumeFinalURLReturnsTheStoredValueAndClearsIt() {
        let manager = CameraManager(autoConfigure: false)
        let url = URL(fileURLWithPath: "/tmp/camera-output.mov")
        manager.finalURL = url

        let consumedURL = manager.consumeFinalURL()

        #expect(consumedURL == url)
        #expect(manager.finalURL == nil)
    }

    @Test
    func stopRecordIsSafeWhenNothingIsBeingRecorded() {
        let manager = CameraManager(autoConfigure: false)

        manager.stopRecord()

        #expect(manager.isRecording == false)
    }

    @Test
    func cameraErrorsCanBeInstantiatedForEachPublicCase() {
        let sampleError = NSError(domain: "CameraManagerTests", code: 1)

        let errors: [CameraError] = [
            .deniedAuthorization,
            .restrictedAuthorization,
            .unknowAuthorization,
            .cameraUnavalible,
            .cannotAddInput,
            .createCaptureInput(sampleError),
            .outputError(sampleError),
        ]

        #expect(errors.count == 7)
    }

    @Test
    func startRecordingUsesTheInjectedOutputAndTemporaryURLFactory() {
        let output = CameraRecordingOutputDouble()
        let expectedURL = URL(fileURLWithPath: "/tmp/camera-phase3.mov")
        let manager = CameraManager(
            maxDuration: 5,
            videoOutput: output,
            sleep: { _ in throw CancellationError() },
            temporaryURLProvider: { expectedURL },
            autoConfigure: false
        )

        manager.recordedDuration = 4
        manager.startRecording()

        #expect(manager.recordedDuration == 0)
        #expect(output.startedURLs == [expectedURL])
        #expect(output.maxDurationConfigurations.isEmpty)
        #expect(manager.isRecording == true)
    }

    @Test
    func toggleRecordingStopsTheInjectedOutputWhenAlreadyRecording() {
        let output = CameraRecordingOutputDouble()
        output.isRecording = true
        let manager = CameraManager(
            videoOutput: output,
            sleep: { _ in },
            autoConfigure: false
        )

        manager.toggleRecording()

        #expect(output.stopRecordingCallCount == 1)
    }

    @Test
    func fileOutputSuccessPublishesTheRecordedURL() async {
        let manager = CameraManager(autoConfigure: false)
        let outputURL = URL(fileURLWithPath: "/tmp/camera-success.mov")

        await MainActor.run {
            manager.fileOutput(
                AVCaptureMovieFileOutput(),
                didFinishRecordingTo: outputURL,
                from: [],
                error: nil
            )
        }

        await waitUntil { manager.finalURL == outputURL }

        #expect(manager.finalURL == outputURL)
        #expect(manager.error == nil)
    }

    @Test
    func fileOutputFailurePublishesTheOutputError() async {
        let manager = CameraManager(autoConfigure: false)
        let sampleError = NSError(domain: "CameraManagerTests", code: 99)

        await MainActor.run {
            manager.fileOutput(
                AVCaptureMovieFileOutput(),
                didFinishRecordingTo: URL(fileURLWithPath: "/tmp/camera-failure.mov"),
                from: [],
                error: sampleError
            )
        }

        await waitUntil {
            if case .outputError = manager.error {
                true
            } else {
                false
            }
        }

        guard case .outputError(let receivedError)? = manager.error else {
            Issue.record("Expected an outputError after a failed recording callback.")
            return
        }

        #expect((receivedError as NSError).domain == sampleError.domain)
        #expect((receivedError as NSError).code == sampleError.code)
    }

    @Test
    func recordingDurationUpdatesCanBeDrivenByTheInjectedSleeper() async {
        let output = CameraRecordingOutputDouble()
        let manager = CameraManager(
            maxDuration: 2,
            videoOutput: output,
            sleep: { _ in },
            autoConfigure: false
        )

        manager.startRecording()
        await Task.yield()
        await Task.yield()
        await Task.yield()

        #expect(manager.recordedDuration == 2)
        #expect(output.stopRecordingCallCount == 1)
        #expect(manager.isRecording == false)
    }

}

private final class CameraRecordingOutputDouble: CameraRecordingOutput {

    // MARK: - Public Properties

    var isRecording = false
    private(set) var startedURLs: [URL] = []
    private(set) var stopRecordingCallCount = 0
    private(set) var maxDurationConfigurations: [Double] = []

    // MARK: - Public Methods

    func startRecording(to outputFileURL: URL, recordingDelegate: AVCaptureFileOutputRecordingDelegate) {
        startedURLs.append(outputFileURL)
        isRecording = true
    }

    func stopRecording() {
        stopRecordingCallCount += 1
        isRecording = false
    }

    func setMaximumRecordedDuration(seconds: Double) {
        maxDurationConfigurations.append(seconds)
    }

    func addToSession(_ session: AVCaptureSession) -> Bool {
        true
    }

}

private func waitUntil(
    iterations: Int = 20,
    condition: @escaping @Sendable () -> Bool
) async {
    for _ in 0..<iterations where !condition() {
        await Task.yield()
    }
}
