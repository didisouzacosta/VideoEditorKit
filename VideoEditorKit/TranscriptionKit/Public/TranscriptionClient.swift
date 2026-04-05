//
//  TranscriptionClient.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

public actor TranscriptionClient: TranscriptionProviding {

    // MARK: - Private Properties

    private let modelStore: any TranscriptionModelStoring
    private let modelDownloader: any ModelDownloading
    private let mediaExtractor: any MediaExtracting
    private let audioPreparer: any AudioPreparing
    private let whisperBridge: any WhisperBridging
    private let normalizationCoordinator: TranscriptionNormalizationCoordinator
    private let statusReporter: (any TranscriptionStatusReporting)?

    // MARK: - Initializer

    public init(
        statusReporter: (any TranscriptionStatusReporting)? = nil
    ) {
        self.modelStore = TranscriptionModelStore()
        self.modelDownloader = URLSessionModelDownloader()
        self.mediaExtractor = AVFoundationMediaExtractor()
        self.audioPreparer = AVFoundationAudioPreparer()
        self.whisperBridge = WhisperBridge()
        self.normalizationCoordinator = TranscriptionNormalizationCoordinator()
        self.statusReporter = statusReporter
    }

    init(
        modelStore: some TranscriptionModelStoring,
        modelDownloader: some ModelDownloading,
        mediaExtractor: some MediaExtracting,
        audioPreparer: some AudioPreparing,
        whisperBridge: some WhisperBridging,
        normalizationCoordinator: TranscriptionNormalizationCoordinator = .init(),
        statusReporter: (any TranscriptionStatusReporting)? = nil
    ) {
        self.modelStore = modelStore
        self.modelDownloader = modelDownloader
        self.mediaExtractor = mediaExtractor
        self.audioPreparer = audioPreparer
        self.whisperBridge = whisperBridge
        self.normalizationCoordinator = normalizationCoordinator
        self.statusReporter = statusReporter
    }

    // MARK: - Public Methods

    public func transcribe(_ request: TranscriptionRequest) async throws -> NormalizedTranscription {
        do {
            try Task.checkCancellation()
            try validate(request)
            report(.idle)

            let modelURL = try await ensureModelIsAvailable(
                for: request.model
            )

            report(.preparingAudio)

            let extractedAudio = try await extractAudio(
                from: request.media
            )
            let shouldCleanupExtractedAudio = extractedAudio.wasExtractedFromVideo

            defer {
                if shouldCleanupExtractedAudio {
                    removeTemporaryFileIfNeeded(
                        at: extractedAudio.audioURL
                    )
                }
            }

            let preparedAudio = try await prepareAudio(
                at: extractedAudio.audioURL
            )

            defer {
                removeTemporaryFileIfNeeded(
                    at: preparedAudio.fileURL
                )
            }

            report(.transcribing)

            let rawResult = try await transcribePreparedAudio(
                preparedAudio,
                modelURL: modelURL,
                request: request
            )
            let normalizedResult = normalizationCoordinator.normalize(
                rawResult,
                fallbackDuration: preparedAudio.duration ?? extractedAudio.duration
            )

            report(.completed)
            return normalizedResult
        } catch is CancellationError {
            throw TranscriptionError.cancelled
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.transcriptionFailed(
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Private Methods

    private func report(_ status: TranscriptionStatus) {
        statusReporter?.report(status)
    }

    private func validate(_ request: TranscriptionRequest) throws {
        let fileURL = request.media.fileURL

        guard fileURL.isFileURL else {
            throw TranscriptionError.invalidAudioFile
        }

        guard !request.model.id.isEmpty else {
            throw TranscriptionError.modelNotFound
        }

        guard !request.model.localFileName.isEmpty else {
            throw TranscriptionError.modelNotFound
        }
    }

    private func removeTemporaryFileIfNeeded(
        at fileURL: URL
    ) {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return
        }

        do {
            try FileManager.default.removeItem(
                at: fileURL
            )
        } catch {
            assertionFailure(
                "Failed to remove temporary transcription file at \(fileURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }

    private func ensureModelIsAvailable(
        for descriptor: RemoteModelDescriptor
    ) async throws -> URL {
        do {
            switch try modelStore.cachedModelState(for: descriptor) {
            case .valid(let localURL):
                return localURL
            case .missing, .invalid:
                let temporaryURL = try modelStore.temporaryDownloadURL(
                    for: descriptor
                )
                let reporter = statusReporter

                defer {
                    removeTemporaryFileIfNeeded(
                        at: temporaryURL
                    )
                }

                report(.downloading(progress: 0))

                try await modelDownloader.downloadModel(
                    from: descriptor.remoteURL,
                    to: temporaryURL
                ) { progress in
                    reporter?.report(
                        .downloading(progress: progress)
                    )
                }

                return try modelStore.installDownloadedModel(
                    from: temporaryURL,
                    for: descriptor
                )
            }
        } catch is CancellationError {
            throw TranscriptionError.cancelled
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.modelDownloadFailed(
                message: error.localizedDescription
            )
        }
    }

    private func extractAudio(
        from source: TranscriptionMediaSource
    ) async throws -> ExtractedAudioSource {
        do {
            return try await mediaExtractor.extractAudioIfNeeded(
                from: source
            )
        } catch is CancellationError {
            throw TranscriptionError.cancelled
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.audioPreparationFailed(
                message: error.localizedDescription
            )
        }
    }

    private func prepareAudio(
        at audioURL: URL
    ) async throws -> PreparedAudio {
        do {
            return try await audioPreparer.prepareAudio(
                at: audioURL
            )
        } catch is CancellationError {
            throw TranscriptionError.cancelled
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.audioPreparationFailed(
                message: error.localizedDescription
            )
        }
    }

    private func transcribePreparedAudio(
        _ preparedAudio: PreparedAudio,
        modelURL: URL,
        request: TranscriptionRequest
    ) async throws -> RawWhisperTranscriptionResult {
        do {
            return try await whisperBridge.transcribe(
                preparedAudio: preparedAudio,
                modelURL: modelURL,
                language: request.language,
                task: request.task
            )
        } catch is CancellationError {
            throw TranscriptionError.cancelled
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.transcriptionFailed(
                message: error.localizedDescription
            )
        }
    }

}
