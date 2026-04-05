import Foundation

struct WhisperBridge: WhisperBridging {

    // MARK: - Private Properties

    private let runner: any WhisperBridgeRunning

    // MARK: - Initializer

    init(
        runner: some WhisperBridgeRunning = WhisperObjectiveCRunner()
    ) {
        self.runner = runner
    }

    // MARK: - Public Methods

    func transcribe(
        preparedAudio: PreparedAudio,
        modelURL: URL,
        language: String?,
        task: TranscriptionTask
    ) async throws -> RawWhisperTranscriptionResult {
        let result = try await runner.run(
            WhisperBridgeRequestPayload(
                preparedAudio: preparedAudio,
                modelURL: modelURL,
                language: language,
                task: task
            )
        )

        return RawWhisperTranscriptionResult(
            text: result.text,
            language: result.language,
            segments: result.segments.map { segment in
                RawWhisperSegment(
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    text: segment.text,
                    words: segment.words.map { word in
                        RawWhisperWord(
                            startTime: word.startTime,
                            endTime: word.endTime,
                            text: word.text
                        )
                    }
                )
            }
        )
    }

}

protocol WhisperBridgeRunning: Sendable {
    func run(_ request: WhisperBridgeRequestPayload) async throws -> WhisperBridgeResultPayload
}

struct WhisperBridgeRequestPayload: Sendable, Hashable {

    // MARK: - Public Properties

    let preparedAudio: PreparedAudio
    let modelURL: URL
    let language: String?
    let task: TranscriptionTask

}

struct WhisperBridgeResultPayload: Sendable, Hashable {

    // MARK: - Public Properties

    let text: String
    let language: String?
    let segments: [WhisperBridgeSegmentPayload]

}

struct WhisperBridgeSegmentPayload: Sendable, Hashable {

    // MARK: - Public Properties

    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let words: [WhisperBridgeWordPayload]

}

struct WhisperBridgeWordPayload: Sendable, Hashable {

    // MARK: - Public Properties

    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String

}

struct WhisperObjectiveCRunner: WhisperBridgeRunning {

    // MARK: - Private Properties

    private let executorFactory: @Sendable () -> TKWhisperBridgeExecutor

    // MARK: - Initializer

    init(
        executorFactory: @escaping @Sendable () -> TKWhisperBridgeExecutor = {
            TKWhisperBridgeExecutor()
        }
    ) {
        self.executorFactory = executorFactory
    }

    // MARK: - Public Methods

    func run(_ request: WhisperBridgeRequestPayload) async throws -> WhisperBridgeResultPayload {
        try await Task.detached {
            let executor = executorFactory()
            let objectiveCRequest = TKWhisperBridgeRequest(
                preparedAudioURL: request.preparedAudio.fileURL,
                modelURL: request.modelURL,
                language: request.language,
                task: objectiveCTask(for: request.task)
            )
            let result: TKWhisperBridgeResult

            do {
                result = try executor.transcribe(
                    objectiveCRequest
                )
            } catch {
                throw map(error as NSError)
            }

            return WhisperBridgeResultPayload(
                text: result.text,
                language: result.language,
                segments: result.segments.map { segment in
                    WhisperBridgeSegmentPayload(
                        startTime: segment.startTime,
                        endTime: segment.endTime,
                        text: segment.text,
                        words: segment.words.map { word in
                            WhisperBridgeWordPayload(
                                startTime: word.startTime,
                                endTime: word.endTime,
                                text: word.text
                            )
                        }
                    )
                }
            )
        }.value
    }

    // MARK: - Private Methods

    private func objectiveCTask(
        for task: TranscriptionTask
    ) -> TKWhisperBridgeTask {
        switch task {
        case .transcribe:
            .transcribe
        case .translate:
            .translate
        }
    }

    private func map(_ error: NSError?) -> TranscriptionError {
        guard let error else {
            return .transcriptionFailed(
                message: "Whisper bridge failed without returning an explicit error."
            )
        }

        if error.domain == TKWhisperBridgeErrorDomain {
            return .transcriptionFailed(
                message: error.localizedDescription
            )
        }

        return .transcriptionFailed(
            message: "\(error.domain) (\(error.code)): \(error.localizedDescription)"
        )
    }

}
