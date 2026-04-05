//
//  TranscriptionKitDependencies.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

protocol TranscriptionModelStoring: Sendable {
    func localModelURL(for descriptor: RemoteModelDescriptor) throws -> URL
}

protocol ModelDownloading: Sendable {
    func downloadModel(
        from remoteURL: URL,
        to temporaryURL: URL,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws
}

protocol MediaExtracting: Sendable {
    func extractAudioIfNeeded(
        from source: TranscriptionMediaSource
    ) async throws -> ExtractedAudioSource
}

protocol AudioPreparing: Sendable {
    func prepareAudio(at audioURL: URL) async throws -> PreparedAudio
}

protocol WhisperBridging: Sendable {
    func transcribe(
        preparedAudio: PreparedAudio,
        modelURL: URL,
        language: String?,
        task: TranscriptionTask
    ) async throws -> RawWhisperTranscriptionResult
}

struct ExtractedAudioSource: Sendable, Hashable {

    // MARK: - Public Properties

    let audioURL: URL
    let duration: TimeInterval?
    let wasExtractedFromVideo: Bool

    // MARK: - Initializer

    init(
        audioURL: URL,
        duration: TimeInterval? = nil,
        wasExtractedFromVideo: Bool
    ) {
        self.audioURL = audioURL
        self.duration = duration
        self.wasExtractedFromVideo = wasExtractedFromVideo
    }

}

struct PreparedAudio: Sendable, Hashable {

    // MARK: - Public Properties

    let fileURL: URL
    let sampleRate: Double
    let channelCount: Int
    let duration: TimeInterval?

    // MARK: - Initializer

    init(
        fileURL: URL,
        sampleRate: Double,
        channelCount: Int,
        duration: TimeInterval? = nil
    ) {
        self.fileURL = fileURL
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.duration = duration
    }

}

struct RawWhisperTranscriptionResult: Sendable, Hashable {

    // MARK: - Public Properties

    let text: String
    let language: String?
    let segments: [RawWhisperSegment]

}

struct RawWhisperSegment: Sendable, Hashable {

    // MARK: - Public Properties

    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let words: [RawWhisperWord]

}

struct RawWhisperWord: Sendable, Hashable {

    // MARK: - Public Properties

    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String

}

struct PlaceholderModelStore: TranscriptionModelStoring {

    // MARK: - Public Methods

    func localModelURL(for descriptor: RemoteModelDescriptor) throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(descriptor.localFileName)
    }

}

struct PlaceholderModelDownloader: ModelDownloading {

    // MARK: - Public Methods

    func downloadModel(
        from remoteURL: URL,
        to temporaryURL: URL,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws {
        progress(nil)
        throw TranscriptionError.modelDownloadFailed(
            message: "Phase 1 scaffolding only. Model downloading is not implemented yet."
        )
    }

}

struct PlaceholderMediaExtractor: MediaExtracting {

    // MARK: - Public Methods

    func extractAudioIfNeeded(
        from source: TranscriptionMediaSource
    ) async throws -> ExtractedAudioSource {
        throw TranscriptionError.audioPreparationFailed(
            message: "Phase 1 scaffolding only. Media extraction is not implemented yet."
        )
    }

}

struct PlaceholderAudioPreparer: AudioPreparing {

    // MARK: - Public Methods

    func prepareAudio(at audioURL: URL) async throws -> PreparedAudio {
        throw TranscriptionError.audioPreparationFailed(
            message: "Phase 1 scaffolding only. Audio preparation is not implemented yet."
        )
    }

}

struct PlaceholderWhisperBridge: WhisperBridging {

    // MARK: - Public Methods

    func transcribe(
        preparedAudio: PreparedAudio,
        modelURL: URL,
        language: String?,
        task: TranscriptionTask
    ) async throws -> RawWhisperTranscriptionResult {
        throw TranscriptionError.transcriptionFailed(
            message: "Phase 1 scaffolding only. Whisper bridge is not implemented yet."
        )
    }

}
