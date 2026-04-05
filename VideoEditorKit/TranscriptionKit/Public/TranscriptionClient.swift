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
        self.modelStore = PlaceholderModelStore()
        self.modelDownloader = PlaceholderModelDownloader()
        self.mediaExtractor = PlaceholderMediaExtractor()
        self.audioPreparer = PlaceholderAudioPreparer()
        self.whisperBridge = PlaceholderWhisperBridge()
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

        let extractedAudio = try await mediaExtractor.extractAudioIfNeeded(
            from: request.media
        )

        _ = try await audioPreparer.prepareAudio(
            at: extractedAudio.audioURL
        )

        let modelURL = try modelStore.localModelURL(
            for: request.model
        )

        _ = modelURL
        _ = modelDownloader
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

}
