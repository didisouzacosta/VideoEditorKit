import AVFoundation
import CoreGraphics
import Foundation
import QuartzCore
import UIKit

struct AVFoundationExportRenderer: VideoExportRendering {
    nonisolated init() {}

    nonisolated func export(
        request: ExportRenderRequest,
        progressHandler: ExportProgressHandler?
    ) async throws -> URL {
        guard request.destinationURL.isFileURL, request.destinationURL.path.isEmpty == false else {
            throw VideoEditorError.exportFailed(reason: Self.invalidDestinationURL)
        }

        if FileManager.default.fileExists(atPath: request.destinationURL.path) {
            throw VideoEditorError.exportFailed(reason: Self.destinationAlreadyExists)
        }

        let preparedComposition = try await makePreparedComposition(from: request)
        guard let exportSession = AVAssetExportSession(
            asset: preparedComposition.composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoEditorError.exportFailed(reason: Self.unableToCreateExportSession)
        }

        exportSession.shouldOptimizeForNetworkUse = false
        exportSession.videoComposition = preparedComposition.videoComposition

        try await export(
            with: exportSession,
            destinationURL: request.destinationURL,
            fileType: .mov
        )
        await progressHandler?(1)

        return request.destinationURL
    }
}

private extension AVFoundationExportRenderer {
    nonisolated static let invalidDestinationURL = "Destination URL is invalid."
    nonisolated static let destinationAlreadyExists = "Destination file already exists."
    nonisolated static let unableToCreateExportSession = "Unable to create export session."
    nonisolated static let exportCancelled = "Export was cancelled."
    nonisolated static let exportFailed = "Export failed."

    struct PreparedComposition {
        nonisolated(unsafe) let composition: AVMutableComposition
        nonisolated let videoComposition: AVVideoComposition

        nonisolated init(
            composition: AVMutableComposition,
            videoComposition: AVVideoComposition
        ) {
            self.composition = composition
            self.videoComposition = videoComposition
        }
    }

    nonisolated func makePreparedComposition(
        from request: ExportRenderRequest
    ) async throws -> PreparedComposition {
        let composition = AVMutableComposition()
        let sourceAsset = request.asset.asset
        let exportTimeRange = cmTimeRange(for: request.timeRange.selectedRange)

        guard let sourceVideoTrack = try await sourceAsset.loadTracks(withMediaType: .video).first else {
            throw VideoEditorError.invalidAsset
        }

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoEditorError.exportFailed(reason: Self.exportFailed)
        }

        do {
            try compositionVideoTrack.insertTimeRange(exportTimeRange, of: sourceVideoTrack, at: .zero)
        } catch {
            throw VideoEditorError.exportFailed(reason: error.localizedDescription)
        }

        if let sourceAudioTrack = try await sourceAsset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            do {
                try compositionAudioTrack.insertTimeRange(exportTimeRange, of: sourceAudioTrack, at: .zero)
            } catch {
                throw VideoEditorError.exportFailed(reason: error.localizedDescription)
            }
        }

        var videoCompositionConfiguration = AVVideoComposition.Configuration()
        videoCompositionConfiguration.renderSize = request.layout.renderSize
        videoCompositionConfiguration.frameDuration = frameDuration(for: request.asset.nominalFrameRate)
        videoCompositionConfiguration.instructions = [
            makeInstruction(
                for: compositionVideoTrack,
                transform: request.layout.transform,
                duration: composition.duration
            )
        ]

        if request.snapshot.captions.isEmpty == false {
            videoCompositionConfiguration.animationTool = makeAnimationTool(from: request)
        }

        let videoComposition = AVVideoComposition(configuration: videoCompositionConfiguration)

        return PreparedComposition(
            composition: composition,
            videoComposition: videoComposition
        )
    }

    nonisolated func makeInstruction(
        for track: AVCompositionTrack,
        transform: CGAffineTransform,
        duration: CMTime
    ) -> AVVideoCompositionInstruction {
        var layerInstructionConfiguration = AVVideoCompositionLayerInstruction.Configuration(assetTrack: track)
        layerInstructionConfiguration.setTransform(transform, at: .zero)

        return AVVideoCompositionInstruction(
            configuration: AVVideoCompositionInstruction.Configuration(
                layerInstructions: [
                    AVVideoCompositionLayerInstruction(configuration: layerInstructionConfiguration)
                ],
                timeRange: CMTimeRange(start: .zero, duration: duration)
            )
        )
    }

    nonisolated func makeAnimationTool(from request: ExportRenderRequest) -> AVVideoCompositionCoreAnimationTool {
        let renderFrame = CGRect(origin: .zero, size: request.layout.renderSize)
        let parentLayer = CALayer()
        parentLayer.frame = renderFrame
        parentLayer.isGeometryFlipped = true

        let videoLayer = CALayer()
        videoLayer.frame = renderFrame
        videoLayer.isGeometryFlipped = true
        parentLayer.addSublayer(videoLayer)

        let safeFrame = CaptionSafeFrameResolver.resolve(
            renderSize: request.layout.renderSize,
            safeArea: request.snapshot.preset.captionSafeArea
        )

        for caption in request.snapshot.captions {
            parentLayer.addSublayer(
                makeCaptionLayer(
                    for: caption,
                    renderSize: request.layout.renderSize,
                    safeFrame: safeFrame,
                    exportRange: request.snapshot.selectedTimeRange
                )
            )
        }

        return AVVideoCompositionCoreAnimationTool(
            configuration: .init(
                postProcessingAsVideoLayer: videoLayer,
                containingLayer: parentLayer
            )
        )
    }

    nonisolated func makeCaptionLayer(
        for caption: Caption,
        renderSize: CGSize,
        safeFrame: CGRect,
        exportRange: ClosedRange<Double>
    ) -> CALayer {
        let frame = CaptionPositionResolver.resolveFrame(
            caption: caption,
            renderSize: renderSize,
            safeFrame: safeFrame
        )
        let font = caption.style.resolvedFont()
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: caption.style.textColor
        ]
        let attributedText = NSAttributedString(
            string: caption.text,
            attributes: textAttributes
        )
        let padding = caption.style.padding

        let containerLayer = CALayer()
        containerLayer.frame = frame
        containerLayer.opacity = 0

        if let backgroundColor = caption.style.backgroundColor {
            let backgroundLayer = CALayer()
            backgroundLayer.frame = containerLayer.bounds
            backgroundLayer.backgroundColor = backgroundColor.cgColor
            backgroundLayer.cornerRadius = caption.style.cornerRadius
            containerLayer.addSublayer(backgroundLayer)
        }

        let textLayer = CATextLayer()
        textLayer.frame = containerLayer.bounds.insetBy(dx: padding, dy: padding)
        textLayer.string = attributedText
        textLayer.alignmentMode = .center
        textLayer.isWrapped = true
        textLayer.contentsScale = 2
        containerLayer.addSublayer(textLayer)

        let startTime = max(0, caption.startTime - exportRange.lowerBound)
        let endTime = max(startTime, caption.endTime - exportRange.lowerBound)
        containerLayer.add(visibilityAnimation(startTime: startTime, endTime: endTime), forKey: "opacity")

        return containerLayer
    }

    nonisolated func visibilityAnimation(
        startTime: Double,
        endTime: Double
    ) -> CAAnimationGroup {
        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.beginTime = AVCoreAnimationBeginTimeAtZero + startTime
        fadeIn.duration = 0.001
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = false

        let fadeOut = CABasicAnimation(keyPath: "opacity")
        fadeOut.fromValue = 1
        fadeOut.toValue = 0
        fadeOut.beginTime = AVCoreAnimationBeginTimeAtZero + endTime
        fadeOut.duration = 0.001
        fadeOut.fillMode = .forwards
        fadeOut.isRemovedOnCompletion = false

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [fadeIn, fadeOut]
        animationGroup.duration = endTime + 0.001
        animationGroup.fillMode = .forwards
        animationGroup.isRemovedOnCompletion = false

        return animationGroup
    }

    nonisolated func frameDuration(for nominalFrameRate: Float) -> CMTime {
        let roundedFrameRate = Int32((nominalFrameRate > 0 ? nominalFrameRate : 30).rounded())
        return CMTime(value: 1, timescale: max(roundedFrameRate, 1))
    }

    nonisolated func cmTimeRange(for range: ClosedRange<Double>) -> CMTimeRange {
        let preferredTimescale: CMTimeScale = 600
        let start = CMTime(seconds: range.lowerBound, preferredTimescale: preferredTimescale)
        let duration = CMTime(
            seconds: range.upperBound - range.lowerBound,
            preferredTimescale: preferredTimescale
        )

        return CMTimeRange(start: start, duration: duration)
    }

    nonisolated func export(
        with session: AVAssetExportSession,
        destinationURL: URL,
        fileType: AVFileType
    ) async throws {
        do {
            try await session.export(to: destinationURL, as: fileType)
        } catch is CancellationError {
            throw VideoEditorError.exportFailed(reason: Self.exportCancelled)
        } catch {
            throw VideoEditorError.exportFailed(reason: error.localizedDescription)
        }
    }
}
