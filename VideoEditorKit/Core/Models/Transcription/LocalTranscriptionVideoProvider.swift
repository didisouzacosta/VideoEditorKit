//
//  LocalTranscriptionVideoProvider.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import Foundation

struct LocalTranscriptionVideoProvider: VideoTranscriptionProvider {

    // MARK: - Private Properties

    private let client: any TranscriptionProviding
    private let modelDescriptor: RemoteModelDescriptor
    private let defaultTask: TranscriptionTask

    // MARK: - Initializer

    init(
        modelDescriptor: RemoteModelDescriptor,
        client: some TranscriptionProviding = TranscriptionClient(),
        defaultTask: TranscriptionTask = .transcribe
    ) {
        self.client = client
        self.modelDescriptor = modelDescriptor
        self.defaultTask = defaultTask
    }

    // MARK: - Public Methods

    func transcribeVideo(input: VideoTranscriptionInput) async throws -> VideoTranscriptionResult {
        let request = try transcriptionRequest(
            from: input
        )
        let normalizedResult = try await client.transcribe(
            request
        )

        return VideoTranscriptionResult(
            segments: normalizedResult.segments.map(videoSegment(from:))
        )
    }

    // MARK: - Private Methods

    private func transcriptionRequest(
        from input: VideoTranscriptionInput
    ) throws -> TranscriptionRequest {
        TranscriptionRequest(
            media: try transcriptionMediaSource(
                from: input.source
            ),
            model: modelDescriptor,
            language: normalizedPreferredLocale(
                input.preferredLocale
            ),
            task: defaultTask
        )
    }

    private func transcriptionMediaSource(
        from source: VideoTranscriptionSource
    ) throws -> TranscriptionMediaSource {
        switch source {
        case .fileURL(let url):
            guard url.isFileURL else {
                throw TranscriptionError.invalidAudioFile
            }

            return .videoFile(url)
        }
    }

    private func normalizedPreferredLocale(
        _ preferredLocale: String?
    ) -> String? {
        let locale = (preferredLocale ?? "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        return locale.isEmpty ? nil : locale
    }

    private func videoSegment(
        from segment: NormalizedSegment
    ) -> TranscriptionSegment {
        TranscriptionSegment(
            id: segment.id,
            startTime: segment.startTime,
            endTime: segment.endTime,
            text: segment.text,
            words: segment.words.map(videoWord(from:))
        )
    }

    private func videoWord(
        from word: NormalizedWord
    ) -> TranscriptionWord {
        TranscriptionWord(
            id: word.id,
            startTime: word.startTime,
            endTime: word.endTime,
            text: word.text
        )
    }

}
