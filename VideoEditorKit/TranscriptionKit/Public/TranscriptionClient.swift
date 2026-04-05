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
        self.statusReporter = statusReporter
    }

    init(
        modelStore: some TranscriptionModelStoring,
        modelDownloader: some ModelDownloading,
        mediaExtractor: some MediaExtracting,
        audioPreparer: some AudioPreparing,
        whisperBridge: some WhisperBridging,
        statusReporter: (any TranscriptionStatusReporting)? = nil
    ) {
        self.modelStore = modelStore
        self.modelDownloader = modelDownloader
        self.mediaExtractor = mediaExtractor
        self.audioPreparer = audioPreparer
        self.whisperBridge = whisperBridge
        self.statusReporter = statusReporter
    }

    // MARK: - Public Methods

    public func transcribe(_ request: TranscriptionRequest) async throws -> NormalizedTranscription {
        try validate(request)
        report(.idle)

        _ = try await ensureModelIsAvailable(
            for: request.model
        )

        report(.preparingAudio)

        let extractedAudio = try await mediaExtractor.extractAudioIfNeeded(
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

        let preparedAudio = try await audioPreparer.prepareAudio(
            at: extractedAudio.audioURL
        )

        defer {
            removeTemporaryFileIfNeeded(
                at: preparedAudio.fileURL
            )
        }

        _ = whisperBridge

        throw TranscriptionError.transcriptionFailed(
            message:
                "Phase 1 scaffolding only. End-to-end transcription orchestration will be completed in later phases."
        )
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
        switch try modelStore.cachedModelState(for: descriptor) {
        case .valid(let localURL):
            return localURL
        case .missing, .invalid:
            let temporaryURL = try modelStore.temporaryDownloadURL(
                for: descriptor
            )

            report(.downloading(progress: 0))

            try await modelDownloader.downloadModel(
                from: descriptor.remoteURL,
                to: temporaryURL
            ) { [weak self] progress in
                Task {
                    await self?.report(
                        .downloading(progress: progress)
                    )
                }
            }

            return try modelStore.installDownloadedModel(
                from: temporaryURL,
                for: descriptor
            )
        }
    }

}
