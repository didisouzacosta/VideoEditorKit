@preconcurrency import AVFoundation
import CoreVideo
import Foundation

enum TranscriptionKitTestMediaFactory {

    // MARK: - Public Methods

    static func makeWorkingDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriptionKitTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        return directoryURL
    }

    static func makeAudioFile(
        in directoryURL: URL,
        fileName: String = "input.caf",
        sampleRate: Double = 44_100,
        channelCount: AVAudioChannelCount = 2,
        duration: TimeInterval = 1
    ) throws -> URL {
        let fileURL = directoryURL.appendingPathComponent(fileName)

        guard
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: channelCount,
                interleaved: true
            )
        else {
            throw TestMediaFactoryError.invalidAudioFormat
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCount
            )
        else {
            throw TestMediaFactoryError.failedToCreateBuffer
        }

        buffer.frameLength = frameCount

        guard let floatChannelData = buffer.floatChannelData else {
            throw TestMediaFactoryError.failedToCreateBuffer
        }

        let sampleCount = Int(frameCount)

        for channelIndex in 0..<Int(channelCount) {
            let channel = floatChannelData[channelIndex]
            for sampleIndex in 0..<sampleCount {
                let sampleTime = Double(sampleIndex) / sampleRate
                channel[sampleIndex] =
                    Float(
                        sin(2 * .pi * 440 * sampleTime)
                    ) * 0.25
            }
        }

        let audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: format.settings
        )
        try audioFile.write(from: buffer)
        return fileURL
    }

    static func makeVideoFileWithAudio(
        in directoryURL: URL,
        fileName: String = "input.mov",
        duration: TimeInterval = 1
    ) async throws -> URL {
        let silentVideoURL = directoryURL.appendingPathComponent("silent.mov")
        let audioURL = try makeAudioFile(
            in: directoryURL,
            fileName: "source-audio.caf",
            duration: duration
        )
        let outputURL = directoryURL.appendingPathComponent(fileName)

        try await makeSilentVideoFile(
            at: silentVideoURL,
            duration: duration
        )

        let videoAsset = AVURLAsset(url: silentVideoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        let composition = AVMutableComposition()
        let videoDuration = try await videoAsset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: videoDuration)

        guard
            let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
            let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
            let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw TestMediaFactoryError.failedToCreateComposition
        }

        try compositionVideoTrack.insertTimeRange(
            timeRange,
            of: videoTrack,
            at: .zero
        )
        try compositionAudioTrack.insertTimeRange(
            timeRange,
            of: audioTrack,
            at: .zero
        )

        guard
            let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            )
        else {
            throw TestMediaFactoryError.failedToCreateExportSession
        }

        try? FileManager.default.removeItem(at: outputURL)
        try await exportSession.export(
            to: outputURL,
            as: .mov
        )

        return outputURL
    }

    // MARK: - Private Methods

    private static func makeSilentVideoFile(
        at fileURL: URL,
        duration: TimeInterval
    ) async throws {
        try? FileManager.default.removeItem(at: fileURL)

        let writer = try AVAssetWriter(
            outputURL: fileURL,
            fileType: .mov
        )
        let width = 32
        let height = 32
        let frameRate = 30
        let frameCount = max(1, Int(duration * Double(frameRate)))
        let frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(frameRate)
        )

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
            ]
        )
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw TestMediaFactoryError.failedToCreateVideo
        }

        writer.add(videoInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let pixelBuffer = try makePixelBuffer(
            width: width,
            height: height
        )

        for frameIndex in 0..<frameCount {
            let presentationTime = CMTimeMultiply(
                frameDuration,
                multiplier: Int32(frameIndex)
            )

            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }

            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw TestMediaFactoryError.failedToCreateVideo
            }
        }

        videoInput.markAsFinished()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writer.finishWriting {
                if let error = writer.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func makePixelBuffer(
        width: Int,
        height: Int
    ) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw TestMediaFactoryError.failedToCreatePixelBuffer
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])

        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        }

        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(
                baseAddress,
                0,
                CVPixelBufferGetDataSize(pixelBuffer)
            )
        }

        return pixelBuffer
    }

}

private enum TestMediaFactoryError: Error {
    case invalidAudioFormat
    case failedToCreateBuffer
    case failedToCreateVideo
    case failedToCreatePixelBuffer
    case failedToCreateComposition
    case failedToCreateExportSession
}
