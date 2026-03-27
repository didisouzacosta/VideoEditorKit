import AVFoundation
import Foundation
import Testing

@testable import VideoEditorKit

@Suite("CameraManagerTests")
struct CameraManagerTests {

    // MARK: - Public Methods

    @Test
    func initialPublicStateMatchesCurrentDefaults() {
        let manager = CameraManager()

        #expect(manager.finalURL == nil)
        #expect(manager.recordedDuration == 0)
        #expect(manager.cameraPosition == .back)
        #expect(manager.maxDuration == 100)
        #expect(manager.isRecording == false)
    }

    @Test
    func consumeFinalURLReturnsTheStoredValueAndClearsIt() {
        let manager = CameraManager()
        let url = URL(fileURLWithPath: "/tmp/camera-output.mov")
        manager.finalURL = url

        let consumedURL = manager.consumeFinalURL()

        #expect(consumedURL == url)
        #expect(manager.finalURL == nil)
    }

    @Test
    func stopRecordIsSafeWhenNothingIsBeingRecorded() {
        let manager = CameraManager()

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

}
