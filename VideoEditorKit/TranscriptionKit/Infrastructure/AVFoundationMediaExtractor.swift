//
//  AVFoundationMediaExtractor.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import AVFoundation
import Foundation

struct AVFoundationMediaExtractor: MediaExtracting {

    // MARK: - Private Properties

    private let rootDirectoryURL: URL?

    // MARK: - Initializer

    init(rootDirectoryURL: URL? = nil) {
        self.rootDirectoryURL = rootDirectoryURL
    }

    // MARK: - Public Methods

    func extractAudioIfNeeded(
        from source: TranscriptionMediaSource
    ) async throws -> ExtractedAudioSource {
        switch source {
        case .audioFile(let audioURL):
            return try await validateAudioSource(
                at: audioURL
            )
        case .videoFile(let videoURL):
            return try await extractAudioFromVideo(
                at: videoURL
            )
        }
    }

    // MARK: - Private Methods

    private func validateAudioSource(
        at audioURL: URL
    ) async throws -> ExtractedAudioSource {
        let asset = try validatedAsset(at: audioURL)
        let audioTracks = try await asset.loadTracks(
            withMediaType: .audio
        )

        guard !audioTracks.isEmpty else {
            throw TranscriptionError.invalidAudioFile
        }

        return ExtractedAudioSource(
            audioURL: audioURL,
            duration: try await duration(for: asset),
            wasExtractedFromVideo: false
        )
    }

    private func extractAudioFromVideo(
        at videoURL: URL
    ) async throws -> ExtractedAudioSource {
        let asset = try validatedAsset(at: videoURL)
        let videoTracks = try await asset.loadTracks(
            withMediaType: .video
        )
        let audioTracks = try await asset.loadTracks(
            withMediaType: .audio
        )

        guard !videoTracks.isEmpty, let audioTrack = audioTracks.first else {
            throw TranscriptionError.invalidAudioFile
        }

        let duration = try await asset.load(.duration)
        let composition = AVMutableComposition()

        guard
            let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw TranscriptionError.audioPreparationFailed(
                message: "Failed to create a mutable composition track for audio extraction."
            )
        }

        do {
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: audioTrack,
                at: .zero
            )
        } catch {
            throw TranscriptionError.audioPreparationFailed(
                message: "Failed to copy the video audio track for extraction: \(error.localizedDescription)"
            )
        }

        let outputURL = try extractedAudioURL()
        try removeItemIfNeeded(at: outputURL)

        guard
            let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetAppleM4A
            )
        else {
            throw TranscriptionError.audioPreparationFailed(
                message: "Failed to create an export session for video audio extraction."
            )
        }

        let sessionBox = UncheckedExportSessionBox(exportSession)

        try await withTaskCancellationHandler {
            try await sessionBox.session.export(
                to: outputURL,
                as: .m4a
            )
        } onCancel: {
            sessionBox.session.cancelExport()
        }

        return ExtractedAudioSource(
            audioURL: outputURL,
            duration: duration.secondsIfFinite,
            wasExtractedFromVideo: true
        )
    }

    private func validatedAsset(
        at fileURL: URL
    ) throws -> AVURLAsset {
        guard fileURL.isFileURL else {
            throw TranscriptionError.invalidAudioFile
        }

        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            throw TranscriptionError.invalidAudioFile
        }

        return AVURLAsset(url: fileURL)
    }

    private func extractedAudioURL() throws -> URL {
        let directoryURL = try extractedAudioDirectoryURL()

        try createDirectoryIfNeeded(at: directoryURL)

        return
            directoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
    }

    private func extractedAudioDirectoryURL() throws -> URL {
        if let rootDirectoryURL {
            return
                rootDirectoryURL
                .appendingPathComponent("ExtractedAudio", isDirectory: true)
        }

        return FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriptionKit", isDirectory: true)
            .appendingPathComponent("ExtractedAudio", isDirectory: true)
    }

    private func createDirectoryIfNeeded(
        at directoryURL: URL
    ) throws {
        guard !FileManager.default.fileExists(atPath: directoryURL.path()) else {
            return
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func removeItemIfNeeded(
        at fileURL: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return
        }

        try FileManager.default.removeItem(at: fileURL)
    }

    private func duration(
        for asset: AVURLAsset
    ) async throws -> TimeInterval? {
        let duration = try await asset.load(.duration)
        return duration.secondsIfFinite
    }

}

private final class UncheckedExportSessionBox: @unchecked Sendable {

    // MARK: - Public Properties

    let session: AVAssetExportSession

    // MARK: - Initializer

    init(_ session: AVAssetExportSession) {
        self.session = session
    }

}

extension CMTime {

    // MARK: - Private Properties

    fileprivate var secondsIfFinite: Double? {
        let value = seconds

        guard value.isFinite, !value.isNaN else {
            return nil
        }

        return value
    }

}
