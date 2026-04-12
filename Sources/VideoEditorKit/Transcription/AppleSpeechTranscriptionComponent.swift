import AVFAudio
import Foundation
import Speech

actor AppleSpeechTranscriptionComponent: VideoTranscriptionComponentProtocol {

    struct Dependencies: Sendable {

        // MARK: - Public Properties

        let extractAudio: @Sendable (URL) async throws -> URL
        let removeExtractedAudio: @Sendable (URL) -> Void
        let resolveAvailability:
            @Sendable (String?) async -> Result<AppleSpeechAvailabilityResolver.Resolution, TranscriptError>
        let transcribeAudio: @Sendable (URL, Locale) async throws -> VideoTranscriptionResult

        // MARK: - Initializer

        init(
            extractAudio: @escaping @Sendable (URL) async throws -> URL,
            removeExtractedAudio: @escaping @Sendable (URL) -> Void,
            resolveAvailability:
                @escaping @Sendable (String?) async ->
                Result<AppleSpeechAvailabilityResolver.Resolution, TranscriptError>,
            transcribeAudio: @escaping @Sendable (URL, Locale) async throws -> VideoTranscriptionResult
        ) {
            self.extractAudio = extractAudio
            self.removeExtractedAudio = removeExtractedAudio
            self.resolveAvailability = resolveAvailability
            self.transcribeAudio = transcribeAudio
        }

        init() {
            let availabilityResolver = AppleSpeechAvailabilityResolver()
            self.init(
                extractAudio: { url in
                    try await VideoAudioExtractionService().extractAudio(from: url)
                },
                removeExtractedAudio: { url in
                    VideoAudioExtractionService().removeExtractedAudioIfNeeded(at: url)
                },
                resolveAvailability: { preferredLocale in
                    await availabilityResolver.resolve(preferredLocale: preferredLocale)
                },
                transcribeAudio: { audioURL, locale in
                    try await Self.transcribeAudioFile(
                        at: audioURL,
                        locale: locale
                    )
                }
            )
        }

        // MARK: - Private Methods

        private static func transcribeAudioFile(
            at audioURL: URL,
            locale: Locale
        ) async throws -> VideoTranscriptionResult {
            let audioFile = try AVAudioFile(forReading: audioURL)
            let transcriber = SpeechTranscriber(
                locale: locale,
                preset: .timeIndexedTranscriptionWithAlternatives
            )
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            var results = [SpeechTranscriber.Result]()

            async let analysisEndTime = analyzer.analyzeSequence(from: audioFile)
            for try await result in transcriber.results {
                guard result.isFinal else { continue }
                results.append(result)
            }
            _ = try await analysisEndTime

            return AppleSpeechTranscriptionMapper().map(results)
        }

    }

    // MARK: - Public Properties

    var state: TranscriptFeatureState {
        currentState
    }

    // MARK: - Private Properties

    private let dependencies: Dependencies

    private var currentState: TranscriptFeatureState = .idle
    private var currentOperationID: UUID?
    private var currentTask: Task<VideoTranscriptionResult, Error>?
    private var currentExtractedAudioURL: URL?

    // MARK: - Initializer

    init(_ dependencies: Dependencies = .init()) {
        self.dependencies = dependencies
    }

    // MARK: - Public Methods

    func availabilityError(
        preferredLocale: String?
    ) async -> TranscriptError? {
        switch await dependencies.resolveAvailability(preferredLocale) {
        case .success:
            nil
        case .failure(let error):
            error
        }
    }

    func transcribeVideo(input: VideoTranscriptionInput) async throws -> VideoTranscriptionResult {
        cancelCurrentTranscriptionIfNeeded(markStateAsCancelled: false)

        let operationID = UUID()
        currentOperationID = operationID
        currentState = .loading

        let dependencies = self.dependencies
        let task = Task<VideoTranscriptionResult, Error> { [weak self] in
            let availability = await dependencies.resolveAvailability(input.preferredLocale)
            let resolution = try Self.resolution(from: availability)
            let sourceURL = try Self.videoURL(from: input.source)
            let audioURL = try await dependencies.extractAudio(sourceURL)
            await self?.registerExtractedAudioURL(audioURL, for: operationID)

            let result = try await dependencies.transcribeAudio(audioURL, resolution.locale)
            guard !result.segments.isEmpty else {
                throw TranscriptError.emptyResult
            }

            return result
        }

        currentTask = task

        do {
            let result = try await task.value
            return try finalizeSuccess(result, for: operationID)
        } catch {
            throw finalizeFailure(error, for: operationID)
        }
    }

    func cancelCurrentTranscription() async {
        cancelCurrentTranscriptionIfNeeded(markStateAsCancelled: true)
    }

    // MARK: - Private Methods

    private static func resolution(
        from availability: Result<AppleSpeechAvailabilityResolver.Resolution, TranscriptError>
    ) throws -> AppleSpeechAvailabilityResolver.Resolution {
        switch availability {
        case .success(let resolution):
            resolution
        case .failure(let error):
            throw error
        }
    }

    private static func videoURL(from source: VideoTranscriptionSource) throws -> URL {
        switch source {
        case .fileURL(let url):
            guard url.isFileURL else {
                throw TranscriptError.invalidVideoSource
            }

            return url
        }
    }

    private func registerExtractedAudioURL(_ url: URL, for operationID: UUID) {
        guard currentOperationID == operationID else {
            dependencies.removeExtractedAudio(url)
            return
        }

        currentExtractedAudioURL = url
    }

    private func finalizeSuccess(
        _ result: VideoTranscriptionResult,
        for operationID: UUID
    ) throws -> VideoTranscriptionResult {
        cleanupExtractedAudioURL(for: operationID)

        guard currentOperationID == operationID else {
            throw CancellationError()
        }

        currentOperationID = nil
        currentTask = nil
        currentState = .loaded
        return result
    }

    private func finalizeFailure(
        _ error: Error,
        for operationID: UUID
    ) -> Error {
        cleanupExtractedAudioURL(for: operationID)

        guard currentOperationID == operationID else {
            return CancellationError()
        }

        currentOperationID = nil
        currentTask = nil

        let transcriptError = mappedError(from: error)
        currentState = .failed(transcriptError)

        if error is CancellationError {
            return CancellationError()
        }

        return transcriptError
    }

    private func cancelCurrentTranscriptionIfNeeded(markStateAsCancelled: Bool) {
        guard let currentTask else { return }

        let operationID = currentOperationID
        self.currentTask = nil
        currentOperationID = nil
        currentTask.cancel()

        if let operationID {
            cleanupExtractedAudioURL(for: operationID)
        }

        if markStateAsCancelled {
            currentState = .failed(.cancelled)
        }
    }

    private func cleanupExtractedAudioURL(for operationID: UUID) {
        guard currentOperationID == operationID || currentOperationID == nil else { return }
        guard let currentExtractedAudioURL else { return }

        dependencies.removeExtractedAudio(currentExtractedAudioURL)
        self.currentExtractedAudioURL = nil
    }

    private func mappedError(from error: Error) -> TranscriptError {
        switch error {
        case let transcriptError as TranscriptError:
            transcriptError
        case is CancellationError:
            .cancelled
        case let extractionError as VideoAudioExtractionService.ExtractionError:
            mappedExtractionError(extractionError)
        default:
            .providerFailure(message: error.localizedDescription)
        }
    }

    private func mappedExtractionError(
        _ error: VideoAudioExtractionService.ExtractionError
    ) -> TranscriptError {
        switch error {
        case .invalidVideoSource:
            .invalidVideoSource
        case .audioTrackNotFound,
            .unableToCreateExportSession,
            .exportFailed:
            .providerFailure(message: error.localizedDescription)
        }
    }

}
