//
//  AVFoundationAudioPreparer.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

@preconcurrency import AVFoundation
import Foundation

struct AVFoundationAudioPreparer: AudioPreparing {

    // MARK: - Private Properties

    private let rootDirectoryURL: URL?
    private let targetSampleRate: Double
    private let targetChannelCount: AVAudioChannelCount

    // MARK: - Initializer

    init(
        rootDirectoryURL: URL? = nil,
        targetSampleRate: Double = 16_000,
        targetChannelCount: AVAudioChannelCount = 1
    ) {
        self.rootDirectoryURL = rootDirectoryURL
        self.targetSampleRate = targetSampleRate
        self.targetChannelCount = targetChannelCount
    }

    // MARK: - Public Methods

    func prepareAudio(at audioURL: URL) async throws -> PreparedAudio {
        guard audioURL.isFileURL else {
            throw TranscriptionError.invalidAudioFile
        }

        guard FileManager.default.fileExists(atPath: audioURL.path()) else {
            throw TranscriptionError.invalidAudioFile
        }

        let outputURL = try preparedAudioURL()
        try removeItemIfNeeded(at: outputURL)

        let asset = AVURLAsset(url: audioURL)
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw TranscriptionError.invalidAudioFile
        }

        let reader: AVAssetReader

        do {
            reader = try AVAssetReader(
                asset: asset
            )
        } catch {
            throw TranscriptionError.audioPreparationFailed(
                message: "Failed to create an audio reader: \(error.localizedDescription)"
            )
        }

        let readerOutput = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: nil
        )

        guard reader.canAdd(readerOutput) else {
            throw TranscriptionError.audioPreparationFailed(
                message: "Failed to attach an audio reader output."
            )
        }

        reader.add(readerOutput)

        let writer: AVAssetWriter

        do {
            writer = try AVAssetWriter(
                outputURL: outputURL,
                fileType: .caf
            )
        } catch {
            throw TranscriptionError.audioPreparationFailed(
                message: "Failed to create the prepared audio writer: \(error.localizedDescription)"
            )
        }

        let writerInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: targetSampleRate,
                AVNumberOfChannelsKey: targetChannelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        )
        writerInput.expectsMediaDataInRealTime = false

        guard writer.canAdd(writerInput) else {
            throw TranscriptionError.audioPreparationFailed(
                message: "Failed to attach an audio writer input."
            )
        }

        writer.add(writerInput)

        guard reader.startReading() else {
            throw TranscriptionError.audioPreparationFailed(
                message: "Failed to start reading the source audio."
            )
        }

        guard writer.startWriting() else {
            throw TranscriptionError.audioPreparationFailed(
                message: "Failed to start writing the prepared audio."
            )
        }

        writer.startSession(atSourceTime: .zero)

        try await writePreparedAudio(
            reader: reader,
            readerOutput: readerOutput,
            writer: writer,
            writerInput: writerInput
        )

        let preparedFile = try AVAudioFile(
            forReading: outputURL
        )
        let duration = Double(preparedFile.length) / preparedFile.processingFormat.sampleRate

        return PreparedAudio(
            fileURL: outputURL,
            sampleRate: preparedFile.processingFormat.sampleRate,
            channelCount: Int(preparedFile.processingFormat.channelCount),
            duration: duration.isFinite ? duration : nil
        )
    }

    // MARK: - Private Methods

    private func writePreparedAudio(
        reader: AVAssetReader,
        readerOutput: AVAssetReaderOutput,
        writer: AVAssetWriter,
        writerInput: AVAssetWriterInput
    ) async throws {
        let bridge = AudioPreparationBridge(
            reader: reader,
            readerOutput: readerOutput,
            writer: writer,
            writerInput: writerInput
        )

        try await bridge.run()
    }

    private func preparedAudioURL() throws -> URL {
        let directoryURL = try preparedAudioDirectoryURL()

        try createDirectoryIfNeeded(at: directoryURL)

        return
            directoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
    }

    private func preparedAudioDirectoryURL() throws -> URL {
        if let rootDirectoryURL {
            return
                rootDirectoryURL
                .appendingPathComponent("PreparedAudio", isDirectory: true)
        }

        return FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriptionKit", isDirectory: true)
            .appendingPathComponent("PreparedAudio", isDirectory: true)
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

}

private final class AudioPreparationBridge: @unchecked Sendable {

    // MARK: - Private Properties

    private let reader: AVAssetReader
    private let readerOutput: AVAssetReaderOutput
    private let writer: AVAssetWriter
    private let writerInput: AVAssetWriterInput
    private let queue = DispatchQueue(label: "TranscriptionKit.AudioPreparation")
    private let lock = NSLock()
    private var isFinished = false

    // MARK: - Initializer

    init(
        reader: AVAssetReader,
        readerOutput: AVAssetReaderOutput,
        writer: AVAssetWriter,
        writerInput: AVAssetWriterInput
    ) {
        self.reader = reader
        self.readerOutput = readerOutput
        self.writer = writer
        self.writerInput = writerInput
    }

    // MARK: - Public Methods

    func run() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writerInput.requestMediaDataWhenReady(on: queue) { [self] in
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        if !writerInput.append(sampleBuffer) {
                            finish(
                                continuation: continuation,
                                error: writer.error
                                    ?? reader.error
                                    ?? TranscriptionError.audioPreparationFailed(
                                        message: "Failed to append a prepared audio sample buffer."
                                    )
                            )
                            return
                        }

                        continue
                    }

                    writerInput.markAsFinished()
                    writer.finishWriting { [self] in
                        if let error = writer.error ?? reader.error {
                            finish(
                                continuation: continuation,
                                error: error
                            )
                            return
                        }

                        if reader.status == .failed {
                            finish(
                                continuation: continuation,
                                error: reader.error
                                    ?? TranscriptionError.audioPreparationFailed(
                                        message: "Audio reading failed while preparing the Whisper input."
                                    )
                            )
                            return
                        }

                        finish(
                            continuation: continuation,
                            error: nil
                        )
                    }
                    return
                }
            }
        }
    }

    // MARK: - Private Methods

    private func finish(
        continuation: CheckedContinuation<Void, Error>,
        error: Error?
    ) {
        lock.lock()

        guard !isFinished else {
            lock.unlock()
            return
        }

        isFinished = true
        lock.unlock()

        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

}
