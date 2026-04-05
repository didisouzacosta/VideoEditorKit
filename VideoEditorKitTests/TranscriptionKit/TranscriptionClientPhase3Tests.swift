import Foundation
import Testing

@testable import VideoEditorKit

@Suite("TranscriptionClientPhase3Tests")
struct TranscriptionClientPhase3Tests {

    // MARK: - Public Methods

    @Test
    func clientReportsPreparingAudioAndCleansTemporaryFilesBeforePhaseFour() async throws {
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
                cachedState: .valid(modelURL)
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
            whisperBridge: PlaceholderWhisperBridge(),
            statusReporter: reporter
        )

        await #expect(throws: TranscriptionError.self) {
            try await client.transcribe(request)
        }

        #expect(reporter.snapshot() == [.idle, .preparingAudio])
        #expect(!FileManager.default.fileExists(atPath: extractedAudioURL.path()))
        #expect(!FileManager.default.fileExists(atPath: preparedAudioURL.path()))
        #expect(FileManager.default.fileExists(atPath: modelURL.path()))
    }

}

private struct StubModelStore: TranscriptionModelStoring {

    // MARK: - Public Properties

    let cachedState: CachedTranscriptionModelState

    // MARK: - Public Methods

    func localModelURL(for descriptor: RemoteModelDescriptor) throws -> URL {
        switch cachedState {
        case .valid(let url), .invalid(let url, issue: _):
            url
        case .missing:
            URL(fileURLWithPath: "/tmp/\(descriptor.localFileName)")
        }
    }

    func temporaryDownloadURL(for descriptor: RemoteModelDescriptor) throws -> URL {
        URL(fileURLWithPath: "/tmp/\(descriptor.localFileName).download")
    }

    func cachedModelState(for descriptor: RemoteModelDescriptor) throws -> CachedTranscriptionModelState {
        cachedState
    }

    func installDownloadedModel(
        from temporaryURL: URL,
        for descriptor: RemoteModelDescriptor
    ) throws -> URL {
        temporaryURL
    }

}

private struct StubModelDownloader: ModelDownloading {

    // MARK: - Public Methods

    func downloadModel(
        from remoteURL: URL,
        to temporaryURL: URL,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws {}

}

private struct StubMediaExtractor: MediaExtracting {

    // MARK: - Public Properties

    let result: ExtractedAudioSource

    // MARK: - Public Methods

    func extractAudioIfNeeded(
        from source: TranscriptionMediaSource
    ) async throws -> ExtractedAudioSource {
        result
    }

}

private struct StubAudioPreparer: AudioPreparing {

    // MARK: - Public Properties

    let result: PreparedAudio

    // MARK: - Public Methods

    func prepareAudio(at audioURL: URL) async throws -> PreparedAudio {
        result
    }

}

private final class LockedStatusReporter: TranscriptionStatusReporting, @unchecked Sendable {

    // MARK: - Private Properties

    private var values: [TranscriptionStatus] = []
    private let lock = NSLock()

    // MARK: - Public Methods

    func report(_ status: TranscriptionStatus) {
        lock.lock()
        values.append(status)
        lock.unlock()
    }

    func snapshot() -> [TranscriptionStatus] {
        lock.lock()
        let snapshot = values
        lock.unlock()
        return snapshot
    }

}
