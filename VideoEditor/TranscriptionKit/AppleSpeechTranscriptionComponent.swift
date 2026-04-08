//
//  AppleSpeechTranscriptionComponent.swift
//  VideoEditorKit
//
//  Created by Codex on 08.04.2026.
//

import Foundation
import VideoEditorKit

actor AppleSpeechTranscriptionComponent: VideoTranscriptionComponentProtocol {

    struct Dependencies: Sendable {

        // MARK: - Public Properties

        let extractAudio: @Sendable (URL) async throws -> URL
        let removeExtractedAudio: @Sendable (URL) -> Void
        let validateAvailability: @Sendable (String?) async throws -> Void
        let transcribeAudio: @Sendable (URL, String?) async throws -> VideoTranscriptionResult

        // MARK: - Initializer

        init(
            extractAudio: @escaping @Sendable (URL) async throws -> URL,
            removeExtractedAudio: @escaping @Sendable (URL) -> Void,
            validateAvailability: @escaping @Sendable (String?) async throws -> Void = { _ in },
            transcribeAudio: @escaping @Sendable (URL, String?) async throws -> VideoTranscriptionResult
        ) {
            self.extractAudio = extractAudio
            self.removeExtractedAudio = removeExtractedAudio
            self.validateAvailability = validateAvailability
            self.transcribeAudio = transcribeAudio
        }

        init(
            service: AppleSpeechTranscriptionService = .init()
        ) {
            self.init(
                extractAudio: { url in
                    try await VideoAudioExtractionService().extractAudio(from: url)
                },
                removeExtractedAudio: { url in
                    VideoAudioExtractionService().removeExtractedAudioIfNeeded(at: url)
                },
                validateAvailability: { preferredLocaleIdentifier in
                    try await service.validateAvailability(
                        preferredLocaleIdentifier: preferredLocaleIdentifier
                    )
                },
                transcribeAudio: { audioURL, preferredLocaleIdentifier in
                    try await service.transcribeAudio(
                        at: audioURL,
                        preferredLocaleIdentifier: preferredLocaleIdentifier
                    )
                }
            )
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

    init(
        dependencies: Dependencies = .init()
    ) {
        self.dependencies = dependencies
    }

    // MARK: - Public Methods

    func transcribeVideo(
        input: VideoTranscriptionInput
    ) async throws -> VideoTranscriptionResult {
        cancelCurrentTranscriptionIfNeeded(markStateAsCancelled: false)

        let operationID = UUID()
        currentOperationID = operationID
        currentState = .loading

        let dependencies = self.dependencies
        let task = Task<VideoTranscriptionResult, Error> { [weak self] in
            let sourceURL = try Self.videoURL(from: input.source)
            let audioURL = try await dependencies.extractAudio(sourceURL)
            await self?.registerExtractedAudioURL(audioURL, for: operationID)

            let result = try await dependencies.transcribeAudio(
                audioURL,
                input.preferredLocale
            )
            guard result.segments.isEmpty == false else {
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

    func availabilityError(
        preferredLocale: String?
    ) async -> TranscriptError? {
        do {
            try await dependencies.validateAvailability(preferredLocale)
            return nil
        } catch {
            return mappedError(from: error)
        }
    }

    // MARK: - Private Methods

    private static func videoURL(
        from source: VideoTranscriptionSource
    ) throws -> URL {
        switch source {
        case .fileURL(let url):
            guard url.isFileURL else {
                throw TranscriptError.invalidVideoSource
            }

            return url
        }
    }

    private func registerExtractedAudioURL(
        _ url: URL,
        for operationID: UUID
    ) {
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

    private func cancelCurrentTranscriptionIfNeeded(
        markStateAsCancelled: Bool
    ) {
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

    private func cleanupExtractedAudioURL(
        for operationID: UUID
    ) {
        guard currentOperationID == operationID || currentOperationID == nil else { return }
        guard let currentExtractedAudioURL else { return }

        dependencies.removeExtractedAudio(currentExtractedAudioURL)
        self.currentExtractedAudioURL = nil
    }

    private func mappedError(
        from error: Error
    ) -> TranscriptError {
        switch error {
        case let transcriptError as TranscriptError:
            transcriptError
        case is CancellationError:
            .cancelled
        case let extractionError as VideoAudioExtractionService.ExtractionError:
            mappedExtractionError(extractionError)
        case let serviceError as AppleSpeechTranscriptionService.ServiceError:
            mappedServiceError(serviceError)
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

    private func mappedServiceError(
        _ error: AppleSpeechTranscriptionService.ServiceError
    ) -> TranscriptError {
        switch error {
        case .invalidAudioSource:
            .invalidVideoSource
        case .emptyResult:
            .emptyResult
        case .transcriptionUnavailable,
            .unsupportedLocale:
            .unavailable(message: error.localizedDescription)
        case .assetPreparationFailed,
            .unableToReadAudioFile:
            .providerFailure(message: error.localizedDescription)
        }
    }

}
