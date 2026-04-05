import Foundation

@testable import VideoEditorKit

final class StubModelStore: @unchecked Sendable, TranscriptionModelStoring {

    // MARK: - Public Properties

    let cachedState: CachedTranscriptionModelState
    let localModelURLValue: URL
    let temporaryDownloadURLValue: URL
    let installedModelURLValue: URL

    private(set) var installRequests: [URL] = []

    // MARK: - Initializer

    init(
        cachedState: CachedTranscriptionModelState,
        localModelURLValue: URL,
        temporaryDownloadURLValue: URL? = nil,
        installedModelURLValue: URL? = nil
    ) {
        self.cachedState = cachedState
        self.localModelURLValue = localModelURLValue
        self.temporaryDownloadURLValue =
            temporaryDownloadURLValue
            ?? localModelURLValue.appendingPathExtension("download")
        self.installedModelURLValue = installedModelURLValue ?? localModelURLValue
    }

    // MARK: - Public Methods

    func localModelURL(for descriptor: RemoteModelDescriptor) throws -> URL {
        localModelURLValue
    }

    func temporaryDownloadURL(for descriptor: RemoteModelDescriptor) throws -> URL {
        temporaryDownloadURLValue
    }

    func cachedModelState(for descriptor: RemoteModelDescriptor) throws -> CachedTranscriptionModelState {
        cachedState
    }

    func installDownloadedModel(
        from temporaryURL: URL,
        for descriptor: RemoteModelDescriptor
    ) throws -> URL {
        installRequests.append(temporaryURL)
        return installedModelURLValue
    }

}

final class StubModelDownloader: @unchecked Sendable, ModelDownloading {

    // MARK: - Private Properties

    private let progressValues: [Double?]
    private let downloadedData: Data?
    private let error: Error?
    private let lock = NSLock()
    private var downloadRequests: [(remoteURL: URL, temporaryURL: URL)] = []

    // MARK: - Initializer

    init(
        progressValues: [Double?] = [],
        downloadedData: Data? = nil,
        error: Error? = nil
    ) {
        self.progressValues = progressValues
        self.downloadedData = downloadedData
        self.error = error
    }

    // MARK: - Public Methods

    func downloadModel(
        from remoteURL: URL,
        to temporaryURL: URL,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws {
        lock.withLock {
            downloadRequests.append((remoteURL: remoteURL, temporaryURL: temporaryURL))
        }

        for value in progressValues {
            progress(value)
        }

        if let downloadedData {
            try downloadedData.write(to: temporaryURL)
        }

        if let error {
            throw error
        }
    }

    func snapshot() -> [(remoteURL: URL, temporaryURL: URL)] {
        lock.withLock {
            downloadRequests
        }
    }

}

struct StubMediaExtractor: MediaExtracting {

    // MARK: - Public Properties

    let result: ExtractedAudioSource

    // MARK: - Public Methods

    func extractAudioIfNeeded(
        from source: TranscriptionMediaSource
    ) async throws -> ExtractedAudioSource {
        result
    }

}

struct StubAudioPreparer: AudioPreparing {

    // MARK: - Public Properties

    let result: PreparedAudio

    // MARK: - Public Methods

    func prepareAudio(at audioURL: URL) async throws -> PreparedAudio {
        result
    }

}

struct StubWhisperBridge: WhisperBridging {

    // MARK: - Private Properties

    private let result: RawWhisperTranscriptionResult?
    private let error: Error?

    // MARK: - Initializer

    init(result: RawWhisperTranscriptionResult) {
        self.result = result
        self.error = nil
    }

    init(error: Error) {
        self.result = nil
        self.error = error
    }

    // MARK: - Public Methods

    func transcribe(
        preparedAudio: PreparedAudio,
        modelURL: URL,
        language: String?,
        task: TranscriptionTask
    ) async throws -> RawWhisperTranscriptionResult {
        if let error {
            throw error
        }

        guard let result else {
            throw TranscriptionError.transcriptionFailed(
                message: "StubWhisperBridge was created without a result."
            )
        }

        return result
    }

}

final class LockedStatusReporter: TranscriptionStatusReporting, @unchecked Sendable {

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
