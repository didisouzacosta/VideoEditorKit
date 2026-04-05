//
//  TranscriptionKitModels.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

public struct TranscriptionRequest: Sendable, Hashable {

    // MARK: - Public Properties

    public let media: TranscriptionMediaSource
    public let model: RemoteModelDescriptor
    public let language: String?
    public let task: TranscriptionTask

    // MARK: - Initializer

    public init(
        media: TranscriptionMediaSource,
        model: RemoteModelDescriptor,
        language: String? = nil,
        task: TranscriptionTask = .transcribe
    ) {
        self.media = media
        self.model = model
        self.language = language
        self.task = task
    }

}

public enum TranscriptionMediaSource: Sendable, Hashable {
    case audioFile(URL)
    case videoFile(URL)

    // MARK: - Public Properties

    public var fileURL: URL {
        switch self {
        case .audioFile(let url), .videoFile(let url):
            url
        }
    }

}

public struct RemoteModelDescriptor: Sendable, Hashable {

    // MARK: - Public Properties

    public let id: String
    public let remoteURL: URL
    public let localFileName: String
    public let expectedSizeInBytes: Int64?
    public let sha256: String?

    // MARK: - Initializer

    public init(
        id: String,
        remoteURL: URL,
        localFileName: String,
        expectedSizeInBytes: Int64? = nil,
        sha256: String? = nil
    ) {
        self.id = id
        self.remoteURL = remoteURL
        self.localFileName = localFileName
        self.expectedSizeInBytes = expectedSizeInBytes
        self.sha256 = sha256
    }

}

public enum TranscriptionTask: String, Sendable, Hashable {
    case transcribe
    case translate
}

public struct NormalizedTranscription: Sendable, Hashable {

    // MARK: - Public Properties

    public let fullText: String
    public let language: String?
    public let duration: TimeInterval?
    public let segments: [NormalizedSegment]

    // MARK: - Initializer

    public init(
        fullText: String,
        language: String? = nil,
        duration: TimeInterval? = nil,
        segments: [NormalizedSegment]
    ) {
        self.fullText = fullText
        self.language = language
        self.duration = duration
        self.segments = segments
    }

}

public struct NormalizedSegment: Sendable, Hashable, Identifiable {

    // MARK: - Public Properties

    public let id: UUID
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let words: [NormalizedWord]

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        words: [NormalizedWord] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.words = words
    }

}

public struct NormalizedWord: Sendable, Hashable, Identifiable {

    // MARK: - Public Properties

    public let id: UUID
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }

}

public enum TranscriptionStatus: Sendable, Equatable {
    case idle
    case downloading(progress: Double?)
    case preparingAudio
    case transcribing
    case completed
}

public enum TranscriptionError: Error, Sendable, Equatable {
    case invalidAudioFile
    case unsupportedAudioFormat
    case modelNotFound
    case modelIntegrityCheckFailed
    case modelDownloadFailed(message: String)
    case audioPreparationFailed(message: String)
    case transcriptionFailed(message: String)
    case cancelled
}

public protocol TranscriptionStatusReporting: Sendable {
    func report(_ status: TranscriptionStatus)
}

public protocol TranscriptionProviding: Sendable {
    func transcribe(_ request: TranscriptionRequest) async throws -> NormalizedTranscription
}
