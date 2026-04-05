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
        let adjusts = Helpers.createColorAdjustsFilters(
            colorAdjusts: video.colorAdjusts
        )

        let usesAdjustsStage = !adjusts.isEmpty
        let usesTranscriptStage = requiresTranscriptStage(editingConfiguration)
        let usesCanvasStage = requiresCanvasStage(editingConfiguration)
        let renderStages = resolvedRenderStages(
            usesAdjustsStage: usesAdjustsStage,
            usesTranscriptStage: usesTranscriptStage,
            usesCropStage: usesCanvasStage
        )

        do {
            let url = try await resizeAndLayerOperation(
                video: video,
                editingConfiguration: editingConfiguration,
                videoQuality: videoQuality,
                progressRange: progressRange(
                    for: .base,
                    activeStages: renderStages
                ),
                onProgress: onProgress
            )

            let adjustedURL = try await applyAdjustsOperation(
                adjusts,
                fromUrl: url,
                progressRange: progressRange(
                    for: .adjusts,
                    activeStages: renderStages
                ),
                onProgress: onProgress
            )
            let transcribedURL = try await applyTranscriptOperation(
                editingConfiguration: editingConfiguration,
                fromUrl: adjustedURL,
                progressRange: progressRange(
                    for: .transcript,
                    activeStages: renderStages
                ),
                onProgress: onProgress
            )
            let croppedURL = try await applyCanvasOperation(
                editingConfiguration: editingConfiguration,
                fromUrl: transcribedURL,
                progressRange: progressRange(
                    for: .crop,
                    activeStages: renderStages
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

    private static func applyAdjustsOperation(
        _ adjusts: [CIFilter],
        fromUrl: URL,
        progressRange: ClosedRange<Double>,
        onProgress: ProgressHandler?
    ) async throws -> URL {
        if adjusts.isEmpty {
            await reportProgress(progressRange.upperBound, via: onProgress)
            return fromUrl
        }

        let asset = AVURLAsset(url: fromUrl)
        let composition = try await asset.makeVideoComposition(applying: adjusts)
        let outputURL = createTempPath()

        guard
            let session = AVAssetExportSession(
                asset: asset,
                presetName: resolvedExportPresetName(
                    appliesVideoComposition: true,
                    isSimulatorEnvironment: isSimulator
                )
            )
        else {
            assertionFailure("Unable to create color adjusts export session.")
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

    private static func applyCanvasOperation(
        editingConfiguration: VideoEditingConfiguration,
        fromUrl: URL,
        progressRange: ClosedRange<Double>,
        onProgress: ProgressHandler?
    ) async throws -> URL {
        guard requiresCanvasStage(editingConfiguration) else {
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
        let renderRequest = await resolvedCanvasRenderRequest(
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            sourcePresentationSize: presentationSize,
            editingConfiguration: editingConfiguration
        )
        let mappingActor = VideoCanvasMappingActor()
        let exportMapping = mappingActor.makeExportMapping(
            request: renderRequest
        )

        guard
            let session = AVAssetExportSession(
                asset: asset,
                presetName: resolvedExportPresetName(
                    appliesVideoComposition: true,
                    isSimulatorEnvironment: isSimulator
                )
            )
        else {
            assertionFailure("Unable to create crop export session.")
            throw ExporterError.cannotCreateExportSession
        }

        session.videoComposition = canvasVideoComposition(
            track: videoTrack,
            contentTransform: exportMapping.contentTransform,
            renderSize: exportMapping.renderSize,
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

    private static func applyTranscriptOperation(
        editingConfiguration: VideoEditingConfiguration,
        fromUrl: URL,
        progressRange: ClosedRange<Double>,
        onProgress: ProgressHandler?
    ) async throws -> URL {
        guard let transcriptDocument = editingConfiguration.transcript.document else {
            await reportProgress(progressRange.upperBound, via: onProgress)
            return fromUrl
        }

        let renderSegments = resolvedTranscriptRenderSegments(
            from: transcriptDocument
        )
        guard !renderSegments.isEmpty else {
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
        let instruction = videoCompositionInstructionForTrackWithSizeAndTime(
            preferredTransform: preferredTransform,
            naturalSize: naturalSize,
            presentationSize: presentationSize,
            renderSize: presentationSize,
            track: videoTrack,
            isMirror: false
        )
        let animationTool = createTranscriptAnimationTool(
            transcriptDocument,
            renderSegments: renderSegments,
            renderSize: presentationSize
        )
        let videoComposition = AVVideoComposition(
            configuration: .init(
                animationTool: animationTool,
                frameDuration: CMTime(value: 1, timescale: 30),
                instructions: [
                    AVVideoCompositionInstruction(
                        configuration: .init(
                            layerInstructions: [instruction],
                            timeRange: trackTimeRange
                        )
                    )
                ],
                renderSize: presentationSize
            )
        )
        let outputURL = createTempPath()

        guard
            let session = AVAssetExportSession(
                asset: asset,
                presetName: resolvedExportPresetName(
                    appliesVideoComposition: true,
                    isSimulatorEnvironment: isSimulator
                )
            )
        else {
            assertionFailure("Unable to create transcript export session.")
            throw ExporterError.cannotCreateExportSession
        }

        session.videoComposition = videoComposition

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

    enum RenderStage: Equatable {
        case base
        case adjusts
        case transcript
        case crop
    }

    private struct TranscriptRenderSegment: Equatable {

        // MARK: - Public Properties

        let text: String
        let timeRange: ClosedRange<Double>
        let style: TranscriptStyle

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
        if let canvasSize = preferredCanvasRenderSize(
            for: sourceSize,
            editingConfiguration: editingConfiguration
        ) {
            return evenPixelSize(for: canvasSize)
        }

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

        guard
            let cropRect = VideoCropPreviewLayout.resolvedGeometry(
                freeformRect: freeformRect,
                in: presentationSize
            )?.sourceRect
        else {
            return CGRect(origin: .zero, size: evenPixelSize(for: presentationSize))
        }

        let width = max(round(cropRect.width / 2) * 2, 2)
        let height = max(round(cropRect.height / 2) * 2, 2)
        let boundedWidth = min(width, presentationSize.width)
        let boundedHeight = min(height, presentationSize.height)
        let originX = min(
            max(round(cropRect.minX), 0),
            max(presentationSize.width - boundedWidth, 0)
        )
        let originY = min(
            max(round(cropRect.minY), 0),
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
        if let canvasSize = preferredCanvasRenderSize(
            for: sourceSize,
            editingConfiguration: editingConfiguration
        ) {
            return canvasSize.height > canvasSize.width ? .portrait : .landscape
        }

        if editingConfiguration.presentation.socialVideoDestination != nil {
            return .portrait
        }

        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return .landscape
        }

        guard let freeformRect = editingConfiguration.crop.freeformRect else {
            return .landscape
        }

        guard
            let cropRect = VideoCropPreviewLayout.resolvedGeometry(
                freeformRect: freeformRect,
                in: sourceSize
            )?.sourceRect
        else { return .landscape }

        guard cropRect.width > 0, cropRect.height > 0 else {
            return .landscape
        }

        return cropRect.height > cropRect.width ? .portrait : .landscape
    }

    static func resolvedExportPresetName(
        appliesVideoComposition: Bool,
        isSimulatorEnvironment: Bool
    ) -> String {
        guard isSimulatorEnvironment else {
            return AVAssetExportPresetHighestQuality
        }

        // `passthrough` ignores videoComposition, which would drop preset/canvas and adjusts renders.
        return appliesVideoComposition
            ? AVAssetExportPresetHighestQuality
            : AVAssetExportPresetPassthrough
    }

    static func resolvedRenderStages(
        usesAdjustsStage: Bool,
        usesTranscriptStage: Bool,
        usesCropStage: Bool
    ) -> [RenderStage] {
        var stages: [RenderStage] = [.base]

        if usesAdjustsStage {
            stages.append(.adjusts)
        }

        if usesTranscriptStage {
            stages.append(.transcript)
        }

        if usesCropStage {
            stages.append(.crop)
        }

        return stages
    }

    private static func requiresCanvasStage(
        _ editingConfiguration: VideoEditingConfiguration
    ) -> Bool {
        let normalizedRotation = editingConfiguration.crop.rotationDegrees
            .truncatingRemainder(dividingBy: 360)

        return editingConfiguration.canvas.snapshot.isIdentity == false
            || editingConfiguration.crop.freeformRect != nil
            || editingConfiguration.crop.isMirrored
            || abs(normalizedRotation) > 0.001
            || editingConfiguration.presentation.socialVideoDestination != nil
    }

    static func requiresTranscriptStage(
        _ editingConfiguration: VideoEditingConfiguration
    ) -> Bool {
        guard editingConfiguration.transcript.featureState == .loaded else { return false }
        guard let transcriptDocument = editingConfiguration.transcript.document else { return false }

        return resolvedTranscriptRenderSegments(
            from: transcriptDocument
        ).isEmpty == false
    }

    private static func preferredCanvasRenderSize(
        for sourceSize: CGSize,
        editingConfiguration: VideoEditingConfiguration
    ) -> CGSize? {
        let preset = resolvedCanvasPreset(
            for: sourceSize,
            editingConfiguration: editingConfiguration
        )

        let shouldPreferCanvasSize =
            editingConfiguration.canvas.snapshot.preset != .original
            || editingConfiguration.presentation.socialVideoDestination != nil
            || editingConfiguration.crop.freeformRect != nil

        guard shouldPreferCanvasSize else { return nil }

        return preset.resolvedExportSize(
            naturalSize: sourceSize,
            freeCanvasSize: editingConfiguration.canvas.snapshot.freeCanvasSize
        )
    }

    private static func resolvedCanvasRenderRequest(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        sourcePresentationSize: CGSize,
        editingConfiguration: VideoEditingConfiguration
    ) async -> VideoCanvasRenderRequest {
        let mappingActor = VideoCanvasMappingActor()
        let snapshot = await resolvedCanvasSnapshot(
            for: sourcePresentationSize,
            editingConfiguration: editingConfiguration,
            mappingActor: mappingActor
        )

        return mappingActor.makeRenderRequest(
            source: VideoCanvasSourceDescriptor(
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                userRotationDegrees: editingConfiguration.crop.rotationDegrees,
                isMirrored: editingConfiguration.crop.isMirrored
            ),
            snapshot: snapshot
        )
    }

    private static func resolvedCanvasSnapshot(
        for sourcePresentationSize: CGSize,
        editingConfiguration: VideoEditingConfiguration,
        mappingActor: VideoCanvasMappingActor
    ) async -> VideoCanvasSnapshot {
        let storedSnapshot = editingConfiguration.canvas.snapshot
        if storedSnapshot != .initial {
            return storedSnapshot
        }

        let preset = resolvedCanvasPreset(
            for: sourcePresentationSize,
            editingConfiguration: editingConfiguration
        )
        let resolvedPreset = mappingActor.resolvePreset(
            preset,
            naturalSize: sourcePresentationSize,
            freeCanvasSize: storedSnapshot.freeCanvasSize
        )

        var snapshot = VideoCanvasSnapshot(
            preset: preset,
            freeCanvasSize: resolvedPreset.exportSize,
            transform: .identity,
            showsSafeAreaOverlay: false
        )

        snapshot.transform = mappingActor.snapshotTransform(
            fromLegacyFreeformRect: editingConfiguration.crop.freeformRect,
            referenceSize: sourcePresentationSize,
            exportSize: resolvedPreset.exportSize
        )

        return snapshot
    }

    private static func resolvedCanvasPreset(
        for sourceSize: CGSize,
        editingConfiguration: VideoEditingConfiguration
    ) -> VideoCanvasPreset {
        let storedPreset = editingConfiguration.canvas.snapshot.preset
        if storedPreset != .original {
            return storedPreset
        }

        if let socialVideoDestination = editingConfiguration.presentation.socialVideoDestination {
            return .social(platform: socialVideoDestination.socialPlatform)
        }

        guard let freeformRect = editingConfiguration.crop.freeformRect else {
            return .original
        }

        let clampedAspectRatio = resolvedLegacyCanvasAspectRatio(
            freeformRect: freeformRect,
            sourceSize: sourceSize
        )

        for preset in VideoCropFormatPreset.editorPresets {
            guard let aspectRatio = preset.aspectRatio else { continue }
            guard let clampedAspectRatio else { continue }
            if abs(clampedAspectRatio - aspectRatio) < 0.001 {
                return VideoCanvasPreset.fromLegacySelection(
                    preset: preset,
                    socialVideoDestination: nil
                )
            }
        }

        let cropRect = resolvedCropRect(
            for: freeformRect,
            in: sourceSize
        )

        return .custom(
            width: max(Int(cropRect.width.rounded()), 2),
            height: max(Int(cropRect.height.rounded()), 2)
        )
    }

    private static func resolvedLegacyCanvasAspectRatio(
        freeformRect: VideoEditingConfiguration.FreeformRect,
        sourceSize: CGSize
    ) -> CGFloat? {
        let cropRect = resolvedCropRect(
            for: freeformRect,
            in: sourceSize
        )

        guard cropRect.width > 0, cropRect.height > 0 else { return nil }

        return cropRect.width / cropRect.height
    }

    private static func exportSession(
        composition: AVMutableComposition, videoComposition: AVVideoComposition, outputURL: URL,
        timeRange: CMTimeRange
    ) throws -> AVAssetExportSession {
        guard
            let export = AVAssetExportSession(
                asset: composition,
                presetName: resolvedExportPresetName(
                    appliesVideoComposition: true,
                    isSimulatorEnvironment: isSimulator
                )
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

    private static func createTranscriptAnimationTool(
        _ transcriptDocument: TranscriptDocument,
        renderSegments: [TranscriptRenderSegment],
        renderSize: CGSize
    ) -> AVVideoCompositionCoreAnimationTool {
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)

        let outputLayer = CALayer()
        outputLayer.frame = CGRect(origin: .zero, size: renderSize)
        outputLayer.addSublayer(videoLayer)

        for segment in renderSegments {
            let overlayLayer = makeTranscriptTextLayer(
                for: segment,
                overlayPosition: transcriptDocument.overlayPosition,
                overlaySize: transcriptDocument.overlaySize,
                renderSize: renderSize
            )
            outputLayer.addSublayer(overlayLayer)
        }

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
        activeStages: [RenderStage]
    ) -> ClosedRange<Double> {
        guard let index = activeStages.firstIndex(of: stage) else { return 1...1 }
        let stageWidth = 1 / Double(activeStages.count)
        let lowerBound = Double(index) * stageWidth
        let upperBound =
            index == activeStages.count - 1
            ? 1
            : Double(index + 1) * stageWidth

        return lowerBound...upperBound
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

    private static func canvasVideoComposition(
        track: AVAssetTrack,
        contentTransform: CGAffineTransform,
        renderSize: CGSize,
        timeRange: CMTimeRange
    ) -> AVVideoComposition {
        var configuration = AVVideoCompositionLayerInstruction.Configuration(assetTrack: track)

        configuration.setTransform(
            contentTransform,
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

    private static func resolvedTranscriptRenderSegments(
        from transcriptDocument: TranscriptDocument
    ) -> [TranscriptRenderSegment] {
        transcriptDocument.segments.compactMap { segment in
            let trimmedText = segment.editedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedText.isEmpty == false else { return nil }
            guard let timeRange = segment.timeMapping.timelineRange else { return nil }
            guard timeRange.upperBound > timeRange.lowerBound else { return nil }

            return TranscriptRenderSegment(
                text: trimmedText,
                timeRange: timeRange,
                style: resolvedTranscriptStyle(
                    for: segment,
                    availableStyles: transcriptDocument.availableStyles
                )
            )
        }
    }

    private static func resolvedTranscriptStyle(
        for segment: EditableTranscriptSegment,
        availableStyles: [TranscriptStyle]
    ) -> TranscriptStyle {
        if let styleID = segment.styleID,
            let style = availableStyles.first(where: { $0.id == styleID })
        {
            return style
        }

        return TranscriptStyle(
            id: UUID(),
            name: "Default",
            fontFamily: "SF Pro Rounded"
        )
    }

    private static func makeTranscriptTextLayer(
        for segment: TranscriptRenderSegment,
        overlayPosition: TranscriptOverlayPosition,
        overlaySize: TranscriptOverlaySize,
        renderSize: CGSize
    ) -> CALayer {
        let layout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: renderSize.width,
            videoHeight: renderSize.height,
            selectedPosition: overlayPosition,
            selectedSize: overlaySize,
            text: segment.text
        )
        let textLayer = CATextLayer()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = resolvedTextAlignment(
            for: segment.style.textAlignment
        )
        let font = resolvedTranscriptFont(
            style: segment.style,
            fontSize: layout.fontSize
        )
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: resolvedUIColor(segment.style.textColor),
            .paragraphStyle: paragraphStyle,
        ]

        if segment.style.hasStroke, let strokeColor = segment.style.strokeColor {
            attributes[.strokeColor] = resolvedUIColor(strokeColor)
            attributes[.strokeWidth] = -3
        }

        textLayer.string = NSAttributedString(
            string: segment.text,
            attributes: attributes
        )
        textLayer.frame = layout.overlayFrame.insetBy(dx: -12, dy: 0)
        textLayer.alignmentMode = resolvedCATextAlignment(
            for: segment.style.textAlignment
        )
        textLayer.isWrapped = true
        textLayer.contentsScale = 2
        textLayer.opacity = 0
        textLayer.add(
            resolvedTranscriptOpacityAnimation(
                for: segment.timeRange
            ),
            forKey: "transcript-opacity-\(segment.text.hashValue)"
        )

        return textLayer
    }

    private static func resolvedTranscriptOpacityAnimation(
        for timeRange: ClosedRange<Double>
    ) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.beginTime = AVCoreAnimationBeginTimeAtZero + timeRange.lowerBound
        animation.duration = max(timeRange.upperBound - timeRange.lowerBound, 1 / 30)
        animation.values = [0, 1, 1, 0]
        animation.keyTimes = [0, 0.001, 0.999, 1]
        animation.isRemovedOnCompletion = false
        animation.fillMode = .both
        return animation
    }

    private static func resolvedTranscriptFont(
        style: TranscriptStyle,
        fontSize: CGFloat
    ) -> UIFont {
        let resolvedFont =
            UIFont(name: style.fontFamily, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)

        guard style.isItalic else { return resolvedFont }

        guard
            let italicDescriptor = resolvedFont.fontDescriptor.withSymbolicTraits(.traitItalic)
        else {
            return UIFont.italicSystemFont(ofSize: fontSize)
        }

        return UIFont(descriptor: italicDescriptor, size: fontSize)
    }

    private static func resolvedTextAlignment(
        for alignment: TranscriptTextAlignment
    ) -> NSTextAlignment {
        switch alignment {
        case .leading:
            .left
        case .center:
            .center
        case .trailing:
            .right
        }
    }

    private static func resolvedCATextAlignment(
        for alignment: TranscriptTextAlignment
    ) -> CATextLayerAlignmentMode {
        switch alignment {
        case .leading:
            .left
        case .center:
            .center
        case .trailing:
            .right
        }
    }

    private static func resolvedUIColor(_ color: RGBAColor) -> UIColor {
        UIColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
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
