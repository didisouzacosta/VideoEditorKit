import Foundation
import Testing

@testable import VideoEditorKit

@Suite("TranscriptionClientPhase3Tests")
struct TranscriptionClientPhase3Tests {

    // MARK: - Public Methods

    @Test
    func clientCleansTemporaryFilesWhenTranscriptionFails() async throws {
        let workingDirectory = try TranscriptionKitTestMediaFactory.makeWorkingDirectory()
        let extractedAudioURL = workingDirectory.appendingPathComponent("extracted.m4a")
        let preparedAudioURL = workingDirectory.appendingPathComponent("prepared.caf")
        let modelURL = workingDirectory.appendingPathComponent("model.bin")
        let remoteURL = try #require(
            URL(string: "https://example.com/base.bin")
        )
        let request = TranscriptionRequest(
            media: .videoFile(
                workingDirectory.appendingPathComponent("input.mov")
            ),
            model: RemoteModelDescriptor(
                id: "base",
                remoteURL: remoteURL,
                localFileName: "base.bin"
            )
        )
        let reporter = LockedStatusReporter()

        try Data([1, 2, 3]).write(to: extractedAudioURL)
        try Data([4, 5, 6]).write(to: preparedAudioURL)
        try Data([7, 8, 9]).write(to: modelURL)

        let client = TranscriptionClient(
            modelStore: StubModelStore(
                cachedState: .valid(modelURL),
                localModelURLValue: modelURL
            ),
            modelDownloader: StubModelDownloader(),
            mediaExtractor: StubMediaExtractor(
                result: ExtractedAudioSource(
                    audioURL: extractedAudioURL,
                    duration: 1,
                    wasExtractedFromVideo: true
                )
            ),
            audioPreparer: StubAudioPreparer(
                result: PreparedAudio(
                    fileURL: preparedAudioURL,
                    sampleRate: 16_000,
                    channelCount: 1,
                    duration: 1
                )
            ),
            whisperBridge: StubWhisperBridge(
                error: TranscriptionError.transcriptionFailed(
                    message: "Simulated bridge failure."
                )
            ),
            statusReporter: reporter
        )

        await #expect(throws: TranscriptionError.self) {
            try await client.transcribe(request)
        }

        #expect(reporter.snapshot() == [.idle, .preparingAudio, .transcribing])
        #expect(!FileManager.default.fileExists(atPath: extractedAudioURL.path()))
        #expect(!FileManager.default.fileExists(atPath: preparedAudioURL.path()))
        #expect(FileManager.default.fileExists(atPath: modelURL.path()))
    }

}
