//
//  VideoTranscriptionProvider.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

protocol VideoTranscriptionProvider: Sendable {
    func transcribeVideo(input: VideoTranscriptionInput) async throws -> VideoTranscriptionResult
}

protocol VideoTranscriptionComponentProtocol: VideoTranscriptionProvider {
    var state: TranscriptFeatureState { get async }
    func cancelCurrentTranscription() async
    func availabilityError(
        preferredLocale: String?
    ) async -> TranscriptError?
}

extension VideoTranscriptionComponentProtocol {

    func availabilityError(
        preferredLocale: String?
    ) async -> TranscriptError? {
        nil
    }
}

struct VideoTranscriptionInput: Hashable, Sendable {

    // MARK: - Public Properties

    let assetIdentifier: String
    let source: VideoTranscriptionSource
    let preferredLocale: String?

}

enum VideoTranscriptionSource: Hashable, Sendable {
    case fileURL(URL)
}

struct VideoTranscriptionResult: Hashable, Sendable {

    // MARK: - Public Properties

    var segments: [TranscriptionSegment] = []

}

struct TranscriptionSegment: Identifiable, Hashable, Sendable {

    // MARK: - Public Properties

    let id: UUID
    let startTime: Double
    let endTime: Double
    let text: String
    var words: [TranscriptionWord] = []

}

struct TranscriptionWord: Identifiable, Hashable, Sendable {

    // MARK: - Public Properties

    let id: UUID
    let startTime: Double
    let endTime: Double
    let text: String

}
