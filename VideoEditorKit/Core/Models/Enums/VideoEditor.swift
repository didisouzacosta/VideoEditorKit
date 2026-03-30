//
//  VideoEditor.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVFoundation
import Foundation
import UIKit

enum VideoEditor {

    typealias ProgressHandler = @Sendable (_ progress: Double) async -> Void

    // MARK: - Public Methods

    static func startRender(
        video: Video,
        editingConfiguration: VideoEditingConfiguration = .initial,
        videoQuality: VideoQuality,
        onProgress: ProgressHandler? = nil
    ) async throws -> URL {
        let corrections = Helpers.createColorCorrectionFilters(
            colorCorrection: video.colorCorrection
        )

        let usesCorrectionsStage = !corrections.isEmpty
        let usesCropStage = editingConfiguration.crop.freeformRect != nil

        do {
            let url = try await resizeAndLayerOperation(
                video: video,
                editingConfiguration: editingConfiguration,
                videoQuality: videoQuality,
                progressRange: progressRange(
                    for: .base,
                    usesCorrectionsStage: usesCorrectionsStage,
                    usesCropStage: usesCropStage
                ),
                onProgress: onProgress
            )

            let correctedURL = try await applyCorrectionsOperation(
                corrections,
                fromUrl: url,
                progressRange: progressRange(
                    for: .corrections,
                    usesCorrectionsStage: usesCorrectionsStage,
                    usesCropStage: usesCropStage
                ),
                onProgress: onProgress
            )
            let croppedURL = try await applyCropOperation(
                editingConfiguration.crop.freeformRect,
                editingConfiguration: editingConfiguration,
                videoQuality: videoQuality,
                fromUrl: correctedURL,
                progressRange: progressRange(
                    for: .crop,
                    usesCorrectionsStage: usesCorrectionsStage,
                    usesCropStage: usesCropStage
                ),
                onProgress: onProgress
            )
            return croppedURL
        } catch {
            throw error
        }
    }

    private static func resizeAndLayerOperation(
        video: Video,
        editingConfiguration: VideoEditingConfiguration,
        videoQuality: VideoQuality,
        progressRange: ClosedRange<Double>,
        onProgress: ProgressHandler?
    ) async throws -> URL {
        let composition = AVMutableComposition()
        let timeRange = getTimeRange(for: video.timelineDuration, with: video.outputRangeDuration)
        let asset = video.asset

        try await setTimeScaleAndAddTracks(
            to: composition, from: asset, audio: video.audio, timeScale: Float64(video.rate),
            videoVolume: video.volume)

        guard let videoTrack = try await composition.loadTracks(withMediaType: .video).first else {
            throw ExporterError.unknow
        }

        let naturalSize = videoTrack.naturalSize
        let videoTrackPreferredTransform = try await videoTrack.load(.preferredTransform)
        let presentationSize = resolvedPresentationSize(
            naturalSize: naturalSize,
            preferredTransform: videoTrackPreferredTransform
        )
        let outputSize = resolvedBaseRenderSize(
            for: presentationSize,
            editingConfiguration: editingConfiguration,
            videoQuality: videoQuality
        )

        let layerInstruction = videoCompositionInstructionForTrackWithSizeAndTime(
            preferredTransform: videoTrackPreferredTransform,
            naturalSize: naturalSize,
            presentationSize: presentationSize,
            renderSize: outputSize,
            track: videoTrack,
            isMirror: video.isMirror
        )

        let animationTool = createAnimationTool(video.videoFrames, video: video, size: outputSize)
        let instruction = AVVideoCompositionInstruction(
            configuration: .init(
                layerInstructions: [layerInstruction],
                timeRange: timeRange
            )
        )

        var configuration = AVVideoComposition.Configuration(
            animationTool: animationTool,
            frameDuration: CMTime(value: 1, timescale: 30),
            instructions: [instruction],
            renderSize: outputSize
        )
        configuration.renderScale = 1

        let videoComposition = AVVideoComposition(configuration: configuration)
        let outputURL = createTempPath()
        let session = try exportSession(
            composition: composition, videoComposition: videoComposition, outputURL: outputURL,
            timeRange: timeRange)

        try await export(
            session,
            to: outputURL,
            as: .mp4,
            progressRange: progressRange,
            onProgress: onProgress
        )

        return outputURL
    }

    private static func applyCorrectionsOperation(
        _ corrections: [CIFilter],
        fromUrl: URL,
        progressRange: ClosedRange<Double>,
        onProgress: ProgressHandler?
    ) async throws -> URL {
        if corrections.isEmpty {
            await reportProgress(progressRange.upperBound, via: onProgress)
            return fromUrl
        }

        let asset = AVURLAsset(url: fromUrl)
        let composition = try await asset.makeVideoComposition(applying: corrections)
        let outputURL = createTempPath()

        guard
            let session = AVAssetExportSession(
                asset: asset,
                presetName: isSimulator ? AVAssetExportPresetPassthrough : AVAssetExportPresetHighestQuality
            )
        else {
            assertionFailure("Unable to create color correction export session.")
            throw ExporterError.cannotCreateExportSession
        }

        session.videoComposition = composition

        try await export(
            session,
            to: outputURL,
            as: .mp4,
            progressRange: progressRange,
            onProgress: onProgress
        )

        return outputURL
    }

    private static func applyCropOperation(
        _ freeformRect: VideoEditingConfiguration.FreeformRect?,
        editingConfiguration: VideoEditingConfiguration,
        videoQuality: VideoQuality,
        fromUrl: URL,
        progressRange: ClosedRange<Double>,
        onProgress: ProgressHandler?
    ) async throws -> URL {
        guard let freeformRect else {
            await reportProgress(progressRange.upperBound, via: onProgress)
            return fromUrl
        }

        let asset = AVURLAsset(url: fromUrl)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExporterError.unknow
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let trackTimeRange = try await videoTrack.load(.timeRange)
        let presentationSize = resolvedPresentationSize(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform
        )
        let cropRect = resolvedCropRect(
            for: freeformRect,
            in: presentationSize
        )
        let outputSize = resolvedCropRenderSize(
            for: presentationSize,
            cropRect: cropRect,
            editingConfiguration: editingConfiguration,
            videoQuality: videoQuality
        )

        guard cropRect.size != presentationSize || outputSize != evenPixelSize(for: presentationSize) else {
            await reportProgress(progressRange.upperBound, via: onProgress)
            return fromUrl
        }

        guard
            let session = AVAssetExportSession(
                asset: asset,
                presetName: isSimulator ? AVAssetExportPresetPassthrough : AVAssetExportPresetHighestQuality
            )
        else {
            assertionFailure("Unable to create crop export session.")
            throw ExporterError.cannotCreateExportSession
        }

        session.videoComposition = cropVideoComposition(
            track: videoTrack,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            cropRect: cropRect,
            renderSize: outputSize,
            timeRange: trackTimeRange
        )

        let outputURL = createTempPath()

        try await export(
            session,
            to: outputURL,
            as: .mp4,
            progressRange: progressRange,
            onProgress: onProgress
        )

        return outputURL
    }
}

extension VideoEditor {

    // MARK: - Private Properties

    private enum RenderStage {
        case base
        case corrections
        case crop
    }

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
    }

    // MARK: - Public Methods

    static func resolvedPresentationSize(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> CGSize {
        let transformedBounds = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
            .standardized
        let resolvedSize = CGSize(
            width: abs(transformedBounds.width),
            height: abs(transformedBounds.height)
        )

        guard resolvedSize.width > 0, resolvedSize.height > 0 else {
            return CGSize(
                width: abs(naturalSize.width),
                height: abs(naturalSize.height)
            )
        }

        return resolvedSize
    }

    static func resolvedRenderSize(
        for sourceSize: CGSize,
        constrainedTo maximumSize: CGSize
    ) -> CGSize {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return evenPixelSize(for: maximumSize)
        }

        guard maximumSize.width > 0, maximumSize.height > 0 else {
            return evenPixelSize(for: sourceSize)
        }

        let widthScale = maximumSize.width / sourceSize.width
        let heightScale = maximumSize.height / sourceSize.height
        let scale = min(widthScale, heightScale)
        let fittedSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )

        return evenPixelSize(for: fittedSize)
    }

    static func resolvedBaseRenderSize(
        for sourceSize: CGSize,
        editingConfiguration: VideoEditingConfiguration,
        videoQuality: VideoQuality
    ) -> CGSize {
        let layout = resolvedBaseRenderLayout(
            for: sourceSize,
            editingConfiguration: editingConfiguration
        )

        return resolvedRenderSize(
            for: sourceSize,
            constrainedTo: videoQuality.size(for: layout)
        )
    }

    static func resolvedOutputRenderSize(
        for sourceSize: CGSize,
        editingConfiguration: VideoEditingConfiguration,
        videoQuality: VideoQuality
    ) -> CGSize {
        let layout = resolvedOutputRenderLayout(
            for: sourceSize,
            editingConfiguration: editingConfiguration
        )

        if layout == .portrait {
            return videoQuality.size(for: layout)
        }

        return resolvedRenderSize(
            for: sourceSize,
            constrainedTo: videoQuality.size(for: layout)
        )
    }

    static func resolvedCropRect(
        for freeformRect: VideoEditingConfiguration.FreeformRect,
        in presentationSize: CGSize
    ) -> CGRect {
        guard presentationSize.width > 0, presentationSize.height > 0 else {
            return CGRect(origin: .zero, size: evenPixelSize(for: CGSize(width: 2, height: 2)))
        }

        let fullRect = CGRect(origin: .zero, size: presentationSize)
        let rawRect = CGRect(
            x: freeformRect.x.clamped(to: 0...1) * presentationSize.width,
            y: freeformRect.y.clamped(to: 0...1) * presentationSize.height,
            width: freeformRect.width.clamped(to: 0...1) * presentationSize.width,
            height: freeformRect.height.clamped(to: 0...1) * presentationSize.height
        )
        let intersection = rawRect.intersection(fullRect)

        guard !intersection.isNull, !intersection.isEmpty else {
            return CGRect(origin: .zero, size: evenPixelSize(for: presentationSize))
        }

        let width = max(round(intersection.width / 2) * 2, 2)
        let height = max(round(intersection.height / 2) * 2, 2)
        let boundedWidth = min(width, presentationSize.width)
        let boundedHeight = min(height, presentationSize.height)
        let originX = min(
            max(round(intersection.minX), 0),
            max(presentationSize.width - boundedWidth, 0)
        )
        let originY = min(
            max(round(intersection.minY), 0),
            max(presentationSize.height - boundedHeight, 0)
        )

        return CGRect(
            x: originX,
            y: originY,
            width: boundedWidth,
            height: boundedHeight
        )
    }

    static func resolvedOutputRenderLayout(
        for sourceSize: CGSize,
        editingConfiguration: VideoEditingConfiguration
    ) -> VideoQuality.RenderLayout {
        if editingConfiguration.presentation.socialVideoDestination != nil {
            return .portrait
        }

        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return .landscape
        }

        guard let freeformRect = editingConfiguration.crop.freeformRect else {
            return .landscape
        }

        let cropRect = resolvedCropRect(
            for: freeformRect,
            in: sourceSize
        )

        guard cropRect.width > 0, cropRect.height > 0 else {
            return .landscape
        }

        return cropRect.height > cropRect.width ? .portrait : .landscape
    }

    private static func exportSession(
        composition: AVMutableComposition, videoComposition: AVVideoComposition, outputURL: URL,
        timeRange: CMTimeRange
    ) throws -> AVAssetExportSession {
        guard
            let export = AVAssetExportSession(
                asset: composition,
                presetName: isSimulator ? AVAssetExportPresetPassthrough : AVAssetExportPresetHighestQuality
            )
        else {
            assertionFailure("Unable to create composition export session.")
            throw ExporterError.cannotCreateExportSession
        }

        export.videoComposition = videoComposition
        export.timeRange = timeRange

        return export
    }

    private static func createAnimationTool(
        _ videoFrame: VideoFrames?,
        video: Video,
        size: CGSize
    ) -> AVVideoCompositionCoreAnimationTool? {
        guard let videoFrame else { return nil }

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: size)

        let outputLayer = CALayer()
        outputLayer.frame = CGRect(origin: .zero, size: size)

        let scale = videoFrame.scale
        let scaleSize = CGSize(width: size.width * scale, height: size.height * scale)
        let centerPoint = CGPoint(
            x: (size.width - scaleSize.width) / 2,
            y: (size.height - scaleSize.height) / 2
        )

        let bgLayer = CALayer()
        bgLayer.frame = CGRect(origin: .zero, size: size)
        bgLayer.backgroundColor = UIColor(videoFrame.frameColor).cgColor
        outputLayer.addSublayer(bgLayer)

        videoLayer.frame = CGRect(origin: centerPoint, size: scaleSize)

        outputLayer.addSublayer(videoLayer)

        return AVVideoCompositionCoreAnimationTool(
            configuration: .init(
                postProcessingAsVideoLayer: videoLayer,
                containingLayer: outputLayer
            )
        )
    }

    private static func setTimeScaleAndAddTracks(
        to composition: AVMutableComposition,
        from asset: AVAsset,
        audio: Audio?,
        timeScale: Float64,
        videoVolume: Float
    ) async throws {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let duration = try await asset.load(.duration)
        let oldTimeRange = CMTimeRangeMake(start: CMTime.zero, duration: duration)
        let destinationTimeRange = CMTimeMultiplyByFloat64(duration, multiplier: (1 / timeScale))

        if let audioTrack = audioTracks.first {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            compositionAudioTrack?.preferredVolume = videoVolume
            try compositionAudioTrack?.insertTimeRange(oldTimeRange, of: audioTrack, at: CMTime.zero)
            compositionAudioTrack?.scaleTimeRange(oldTimeRange, toDuration: destinationTimeRange)

            let audioPreferredTransform = try await audioTrack.load(.preferredTransform)
            compositionAudioTrack?.preferredTransform = audioPreferredTransform
        }

        if let videoTrack = videoTracks.first {
            let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)

            try compositionVideoTrack?.insertTimeRange(oldTimeRange, of: videoTrack, at: CMTime.zero)
            compositionVideoTrack?.scaleTimeRange(oldTimeRange, toDuration: destinationTimeRange)

            let videoPreferredTransform = try await videoTrack.load(.preferredTransform)
            compositionVideoTrack?.preferredTransform = videoPreferredTransform
        }

        if let audio {
            let asset = AVURLAsset(url: audio.url)
            guard let secondAudioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                return
            }
            let secondAudioDuration = try await asset.load(.duration)
            let secondAudioTimeRange = CMTimeRange(
                start: .zero,
                duration: CMTimeMinimum(duration, secondAudioDuration)
            )

            guard secondAudioTimeRange.duration > .zero else {
                return
            }

            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            compositionAudioTrack?.preferredVolume = audio.volume
            try compositionAudioTrack?.insertTimeRange(
                secondAudioTimeRange, of: secondAudioTrack, at: CMTime.zero)
            compositionAudioTrack?.scaleTimeRange(
                secondAudioTimeRange,
                toDuration: CMTimeMultiplyByFloat64(
                    secondAudioTimeRange.duration,
                    multiplier: (1 / timeScale)
                )
            )
        }
    }

    private static func export(
        _ session: AVAssetExportSession,
        to outputURL: URL,
        as fileType: AVFileType,
        progressRange: ClosedRange<Double>,
        onProgress: ProgressHandler?
    ) async throws {
        await reportProgress(progressRange.lowerBound, via: onProgress)
        let sessionBox = UncheckedExportSessionBox(session)

        let progressTask = Task {
            while !Task.isCancelled {
                let sessionProgress = Double(sessionBox.session.progress).clamped(to: 0...1)
                let mappedProgress =
                    progressRange.lowerBound
                    + (progressRange.upperBound - progressRange.lowerBound) * sessionProgress

                await reportProgress(mappedProgress, via: onProgress)

                try? await Task.sleep(for: .milliseconds(120))
            }
        }

        defer {
            progressTask.cancel()
        }

        try await withTaskCancellationHandler {
            try await session.export(to: outputURL, as: fileType)
        } onCancel: {
            sessionBox.session.cancelExport()
        }

        try Task.checkCancellation()
        await reportProgress(progressRange.upperBound, via: onProgress)
    }

    private static func reportProgress(
        _ progress: Double,
        via onProgress: ProgressHandler?
    ) async {
        guard let onProgress else { return }
        await onProgress(progress.clamped(to: 0...1))
    }

    private static func getTimeRange(for duration: Double, with timeRange: ClosedRange<Double>)
        -> CMTimeRange
    {
        let start = timeRange.lowerBound.clamped(to: 0...duration)
        let end = timeRange.upperBound.clamped(to: start...duration)
        let startTime = CMTimeMakeWithSeconds(start, preferredTimescale: 1000)
        let endTime = CMTimeMakeWithSeconds(end, preferredTimescale: 1000)
        let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
        return timeRange
    }

    private static func progressRange(
        for stage: RenderStage,
        usesCorrectionsStage: Bool,
        usesCropStage: Bool
    ) -> ClosedRange<Double> {
        switch (usesCorrectionsStage, usesCropStage, stage) {
        case (false, false, .base):
            0...1
        case (true, false, .base), (false, true, .base):
            0...0.7
        case (false, true, .crop), (true, false, .corrections):
            0.7...1
        case (true, true, .base):
            0...0.55
        case (true, true, .corrections):
            0.55...0.8
        case (true, true, .crop):
            0.8...1
        default:
            1...1
        }
    }

    private static func videoCompositionInstructionForTrackWithSizeAndTime(
        preferredTransform: CGAffineTransform,
        naturalSize: CGSize,
        presentationSize: CGSize,
        renderSize: CGSize,
        track: AVAssetTrack,
        isMirror: Bool
    ) -> AVVideoCompositionLayerInstruction {
        var configuration = AVVideoCompositionLayerInstruction.Configuration(assetTrack: track)
        let transformedBounds = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
            .standardized
        let normalizedTransform = preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -transformedBounds.minX,
                y: -transformedBounds.minY
            )
        )
        let widthScale = renderSize.width / max(presentationSize.width, 1)
        let heightScale = renderSize.height / max(presentationSize.height, 1)
        let scaleFactor = min(widthScale, heightScale)
        let scaledContentSize = CGSize(
            width: presentationSize.width * scaleFactor,
            height: presentationSize.height * scaleFactor
        )
        let centerOffset = CGAffineTransform(
            translationX: (renderSize.width - scaledContentSize.width) / 2,
            y: (renderSize.height - scaledContentSize.height) / 2
        )

        var finalTransform =
            normalizedTransform
            .concatenating(CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
            .concatenating(centerOffset)

        if isMirror {
            let mirrorTransform = CGAffineTransform(translationX: renderSize.width, y: 0)
                .scaledBy(x: -1, y: 1)
            finalTransform = finalTransform.concatenating(mirrorTransform)
        }

        configuration.setTransform(finalTransform, at: .zero)

        return AVVideoCompositionLayerInstruction(configuration: configuration)
    }

    private static func cropVideoComposition(
        track: AVAssetTrack,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        cropRect: CGRect,
        renderSize: CGSize,
        timeRange: CMTimeRange
    ) -> AVVideoComposition {
        var configuration = AVVideoCompositionLayerInstruction.Configuration(assetTrack: track)
        let transformedBounds = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
            .standardized
        let normalizedTransform = preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -transformedBounds.minX,
                y: -transformedBounds.minY
            )
        )
        let cropTransform = CGAffineTransform(
            translationX: -cropRect.minX,
            y: -cropRect.minY
        )
        let widthScale = renderSize.width / max(cropRect.width, 1)
        let heightScale = renderSize.height / max(cropRect.height, 1)

        configuration.setTransform(
            normalizedTransform
                .concatenating(cropTransform)
                .concatenating(CGAffineTransform(scaleX: widthScale, y: heightScale)),
            at: .zero
        )

        let instruction = AVVideoCompositionInstruction(
            configuration: .init(
                layerInstructions: [AVVideoCompositionLayerInstruction(configuration: configuration)],
                timeRange: timeRange
            )
        )

        return AVVideoComposition(
            configuration: .init(
                frameDuration: CMTime(value: 1, timescale: 30),
                instructions: [instruction],
                renderSize: renderSize
            )
        )
    }

    private static func resolvedBaseRenderLayout(
        for sourceSize: CGSize,
        editingConfiguration: VideoEditingConfiguration
    ) -> VideoQuality.RenderLayout {
        let outputLayout = resolvedOutputRenderLayout(
            for: sourceSize,
            editingConfiguration: editingConfiguration
        )

        guard outputLayout == .portrait else {
            return .landscape
        }

        guard let freeformRect = editingConfiguration.crop.freeformRect else {
            return .portrait
        }

        return isFullFrameCrop(freeformRect) ? .portrait : .landscape
    }

    private static func resolvedCropRenderSize(
        for sourceSize: CGSize,
        cropRect: CGRect,
        editingConfiguration: VideoEditingConfiguration,
        videoQuality: VideoQuality
    ) -> CGSize {
        let outputLayout = resolvedOutputRenderLayout(
            for: sourceSize,
            editingConfiguration: editingConfiguration
        )

        guard outputLayout == .portrait else {
            return evenPixelSize(for: cropRect.size)
        }

        return videoQuality.size(for: outputLayout)
    }

    private static func isFullFrameCrop(
        _ freeformRect: VideoEditingConfiguration.FreeformRect
    ) -> Bool {
        abs(freeformRect.x) < 0.0001
            && abs(freeformRect.y) < 0.0001
            && abs(freeformRect.width - 1) < 0.0001
            && abs(freeformRect.height - 1) < 0.0001
    }

    private static func createTempPath() -> URL {
        let fileName = "edited-video-\(UUID().uuidString).mp4"
        let tempURL = URL.temporaryDirectory.appending(path: fileName)
        FileManager.default.removeIfExists(for: tempURL)
        return tempURL
    }

    private static func evenPixelSize(for size: CGSize) -> CGSize {
        CGSize(
            width: max(round(size.width / 2) * 2, 2),
            height: max(round(size.height / 2) * 2, 2)
        )
    }

}

private struct UncheckedExportSessionBox: @unchecked Sendable {

    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }

}

enum ExporterError: Error, LocalizedError {
    // MARK: - Public Properties

    case unknow

    case cancelled

    case cannotCreateExportSession

    case failed

    var errorDescription: String? {
        switch self {
        case .unknow:
            return "An unexpected error happened while preparing the export."
        case .cancelled:
            return "The export was cancelled before the final video was generated."
        case .cannotCreateExportSession:
            return "The export session could not be created for this video."
        case .failed:
            return "The video could not be exported. Please try again."
        }
    }
}

extension Double {

    // MARK: - Public Properties

    var degTorad: Double {
        return self * .pi / 180
    }

    // MARK: - Public Methods

    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }

}
