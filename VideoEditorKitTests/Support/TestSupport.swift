@preconcurrency import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import UIKit

@testable import VideoEditorKit

enum TestFixtureError: Error {

    // MARK: - Public Properties

    case unableToCreatePixelBuffer
    case unableToCreateContext
    case failedToAppendFrame
    case failedToFinishWriting

}

enum TestFixtures {

    // MARK: - Public Methods

    static func temporaryURL(fileExtension: String) -> URL {
        let url = URL.temporaryDirectory.appending(
            path: "VideoEditorKitTests-\(UUID().uuidString).\(fileExtension)"
        )
        FileManager.default.removeIfExists(for: url)
        return url
    }

    static func createTemporaryFile(
        fileExtension: String = "tmp",
        contents: Data = Data("fixture".utf8)
    ) throws -> URL {
        let url = temporaryURL(fileExtension: fileExtension)
        try contents.write(to: url)
        return url
    }

    static func makeSolidImage(
        size: CGSize = CGSize(width: 40, height: 20),
        color: UIColor = .systemBlue,
        scale: CGFloat = 1
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func createTemporaryVideo(
        size: CGSize = CGSize(width: 48, height: 24),
        frameCount: Int = 30,
        framesPerSecond: Int32 = 30,
        color: UIColor = .systemRed,
        transform: CGAffineTransform = .identity
    ) async throws -> URL {
        let outputURL = temporaryURL(fileExtension: "mp4")
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let writerBox = UncheckedAssetWriterBox(writer)

        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.transform = transform
        input.expectsMediaDataInRealTime = false

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let resolvedFrameCount = max(frameCount, 1)

        for frameIndex in 0..<resolvedFrameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(10))
            }

            let pixelBuffer = try makePixelBuffer(size: size, color: color)
            let presentationTime = CMTime(
                value: CMTimeValue(frameIndex),
                timescale: framesPerSecond
            )

            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? TestFixtureError.failedToAppendFrame
            }
        }

        input.markAsFinished()

        try await withCheckedThrowingContinuation { continuation in
            writer.finishWriting {
                switch writerBox.writer.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(
                        throwing: writerBox.writer.error ?? TestFixtureError.failedToFinishWriting
                    )
                default:
                    continuation.resume(throwing: TestFixtureError.failedToFinishWriting)
                }
            }
        }

        return outputURL
    }

    // MARK: - Private Methods

    private static func makePixelBuffer(
        size: CGSize,
        color: UIColor
    ) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes =
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            ] as CFDictionary

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw TestFixtureError.unableToCreatePixelBuffer
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(pixelBuffer),
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )
        else {
            throw TestFixtureError.unableToCreateContext
        }

        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        return pixelBuffer
    }

}

private struct UncheckedAssetWriterBox: @unchecked Sendable {

    let writer: AVAssetWriter

    init(_ writer: AVAssetWriter) {
        self.writer = writer
    }

}
