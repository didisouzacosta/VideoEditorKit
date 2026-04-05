import AVFoundation
import Foundation
import Testing

@testable import VideoEditorKit

@Suite("AVFoundationAudioPreparerTests")
struct AVFoundationAudioPreparerTests {

    // MARK: - Public Methods

    @Test
    func preparerConvertsAudioIntoMonoPCMAt16kHz() async throws {
        let workingDirectory = try TranscriptionKitTestMediaFactory.makeWorkingDirectory()
        let audioURL = try TranscriptionKitTestMediaFactory.makeAudioFile(
            in: workingDirectory,
            sampleRate: 44_100,
            channelCount: 2
        )
        let preparer = AVFoundationAudioPreparer(
            rootDirectoryURL: workingDirectory
        )

        let preparedAudio = try await preparer.prepareAudio(
            at: audioURL
        )
        let preparedFile = try AVAudioFile(
            forReading: preparedAudio.fileURL
        )

        #expect(preparedAudio.fileURL != audioURL)
        #expect(preparedAudio.fileURL.pathExtension == "caf")
        #expect(preparedAudio.sampleRate == 16_000)
        #expect(preparedAudio.channelCount == 1)
        #expect(FileManager.default.fileExists(atPath: preparedAudio.fileURL.path()))
        #expect(preparedFile.processingFormat.sampleRate == 16_000)
        #expect(preparedFile.processingFormat.channelCount == 1)
    }

    @Test
    func preparerRejectsMissingLocalFiles() async {
        let preparer = AVFoundationAudioPreparer()
        let missingURL = URL(fileURLWithPath: "/tmp/transcription-kit-missing-\(UUID().uuidString).caf")

        await #expect(throws: TranscriptionError.self) {
            try await preparer.prepareAudio(
                at: missingURL
            )
        }
    }

}
