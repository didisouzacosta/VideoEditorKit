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

    ///The renderer is made up of half-sequential operations:
    static func startRender(video: Video, videoQuality: VideoQuality) async throws -> URL {
        do {
            let url = try await resizeAndLayerOperation(video: video, videoQuality: videoQuality)
            let finalUrl = try await applyFiltersOperations(video, fromUrl: url)
            return finalUrl
        } catch {
            throw error
        }
    }

    ///Cut, resizing, rotate and set quality
    private static func resizeAndLayerOperation(
        video: Video,
        videoQuality: VideoQuality
    ) async throws -> URL {

        let composition = AVMutableComposition()

        let timeRange = getTimeRange(for: video.originalDuration, with: video.rangeDuration)
        let asset = video.asset

        ///Set new timeScale
        try await setTimeScaleAndAddTracks(
            to: composition, from: asset, audio: video.audio, timeScale: Float64(video.rate),
            videoVolume: video.volume)

        ///Get new timeScale video track
        guard let videoTrack = try await composition.loadTracks(withMediaType: .video).first else {
            throw ExporterError.unknow
        }

        ///Prepair new video size
        let naturalSize = videoTrack.naturalSize
        let videoTrackPreferredTransform = try await videoTrack.load(.preferredTransform)
        let outputSize = getSizeFromOrientation(
            newSize: videoQuality.size, videoTrackPreferredTransform: videoTrackPreferredTransform)

        ///Create layerInstructions and set new size, scale, mirror
        let layerInstruction = videoCompositionInstructionForTrackWithSizeAndTime(

            preferredTransform: videoTrackPreferredTransform,
            naturalSize: naturalSize,
            newSize: outputSize,
            track: videoTrack,
            scale: video.videoFrames?.scale ?? 1,
            isMirror: video.isMirror
        )

        ///Create mutable video composition
        let videoComposition = AVMutableVideoComposition()
        ///Set rander video  size
        videoComposition.renderSize = outputSize
        ///Set frame duration 30fps
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)

        ///Create background layer color and scale video
        createLayers(
            video.videoFrames, video: video, size: outputSize, videoComposition: videoComposition)

        ///Set Video Composition Instruction
        let instruction = AVMutableVideoCompositionInstruction()

        ///Set time range
        instruction.timeRange = timeRange
        instruction.layerInstructions = [layerInstruction]

        ///Set instruction in videoComposition
        videoComposition.instructions = [instruction]

        ///Create file path in temp directory
        let outputURL = createTempPath()

        ///Create exportSession
        let session = try exportSession(
            composition: composition, videoComposition: videoComposition, outputURL: outputURL,
            timeRange: timeRange)

        try await session.export(to: outputURL, as: .mp4)
        return outputURL
    }

    ///Adding filters
    private static func applyFiltersOperations(_ video: Video, fromUrl: URL) async throws -> URL {

        let filters = Helpers.createFilters(
            mainFilter: CIFilter(name: video.filterName ?? ""), video.colorCorrection)

        if filters.isEmpty {
            return fromUrl
        }
        let asset = AVURLAsset(url: fromUrl)
        let composition = try await asset.setFilters(filters)

        let outputURL = createTempPath()
        //export the video to as per your requirement conversion

        ///Create exportSession
        guard
            let session = AVAssetExportSession(
                asset: asset,
                presetName: isSimulator ? AVAssetExportPresetPassthrough : AVAssetExportPresetHighestQuality
            )
        else {
            assertionFailure("Unable to create filter export session.")
            throw ExporterError.cannotCreateExportSession
        }
        session.videoComposition = composition
        try await session.export(to: outputURL, as: .mp4)
        return outputURL
    }
}

//MARK: - Helpers
extension VideoEditor {

    private static func exportSession(
        composition: AVMutableComposition, videoComposition: AVMutableVideoComposition, outputURL: URL,
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

    private static func createLayers(
        _ videoFrame: VideoFrames?, video: Video, size: CGSize,
        videoComposition: AVMutableVideoComposition
    ) {

        guard let videoFrame else { return }

        let color = videoFrame.frameColor
        let scale = videoFrame.scale
        let scaleSize = CGSize(width: size.width * scale, height: size.height * scale)
        let centerPoint = CGPoint(
            x: (size.width - scaleSize.width) / 2, y: (size.height - scaleSize.height) / 2)

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: centerPoint, size: scaleSize)
        let bgLayer = CALayer()
        bgLayer.frame = CGRect(origin: .zero, size: size)
        bgLayer.backgroundColor = UIColor(color).cgColor

        let outputLayer = CALayer()
        outputLayer.frame = CGRect(origin: .zero, size: size)

        outputLayer.addSublayer(bgLayer)
        outputLayer.addSublayer(videoLayer)

        if !video.textBoxes.isEmpty {
            for text in video.textBoxes {
                let position = convertSize(text.offset, fromFrame: video.geometrySize, toFrame: size)
                let textLayer = createTextLayer(
                    with: text, size: size, position: position.size, ratio: position.ratio,
                    duration: video.totalDuration)
                outputLayer.addSublayer(textLayer)
            }
        }

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: outputLayer)
    }

    ///Set new time scale for audio and video tracks
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
        //TotalTimeRange
        let oldTimeRange = CMTimeRangeMake(start: CMTime.zero, duration: duration)
        let destinationTimeRange = CMTimeMultiplyByFloat64(duration, multiplier: (1 / timeScale))
        // set new time range in audio track
        if let audioTrack = audioTracks.first {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            compositionAudioTrack?.preferredVolume = videoVolume
            try compositionAudioTrack?.insertTimeRange(oldTimeRange, of: audioTrack, at: CMTime.zero)
            compositionAudioTrack?.scaleTimeRange(oldTimeRange, toDuration: destinationTimeRange)

            let audioPreferredTransform = try await audioTrack.load(.preferredTransform)
            compositionAudioTrack?.preferredTransform = audioPreferredTransform
        }

        // set new time range in video track
        if let videoTrack = videoTracks.first {
            let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)

            try compositionVideoTrack?.insertTimeRange(oldTimeRange, of: videoTrack, at: CMTime.zero)
            compositionVideoTrack?.scaleTimeRange(oldTimeRange, toDuration: destinationTimeRange)

            let videoPreferredTransform = try await videoTrack.load(.preferredTransform)
            compositionVideoTrack?.preferredTransform = videoPreferredTransform
        }

        // Adding audio
        if let audio {
            let asset = AVURLAsset(url: audio.url)
            guard let secondAudioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                return
            }
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            compositionAudioTrack?.preferredVolume = audio.volume
            try compositionAudioTrack?.insertTimeRange(
                oldTimeRange, of: secondAudioTrack, at: CMTime.zero)
            compositionAudioTrack?.scaleTimeRange(oldTimeRange, toDuration: destinationTimeRange)
        }
    }

    ///create CMTimeRange
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

    ///set video size for AVMutableVideoCompositionLayerInstruction
    private static func videoCompositionInstructionForTrackWithSizeAndTime(
        preferredTransform: CGAffineTransform, naturalSize: CGSize, newSize: CGSize,
        track: AVAssetTrack, scale: Double, isMirror: Bool
    ) -> AVMutableVideoCompositionLayerInstruction {

        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let assetInfo = orientationFromTransform(preferredTransform)

        var aspectFillRatio: CGFloat = 1
        if naturalSize.height < naturalSize.width {
            aspectFillRatio = newSize.height / naturalSize.height
        } else {
            aspectFillRatio = newSize.width / naturalSize.width
        }

        let scaleFactor = CGAffineTransform(scaleX: aspectFillRatio, y: aspectFillRatio)

        if assetInfo.isPortrait {

            let posX = newSize.width / 2 - (naturalSize.height * aspectFillRatio) / 2
            let posY = newSize.height / 2 - (naturalSize.width * aspectFillRatio) / 2
            let moveFactor = CGAffineTransform(translationX: posX, y: posY)
            instruction.setTransform(
                preferredTransform.concatenating(scaleFactor).concatenating(moveFactor), at: .zero)

        } else {
            let posX = newSize.width / 2 - (naturalSize.width * aspectFillRatio) / 2
            let posY = newSize.height / 2 - (naturalSize.height * aspectFillRatio) / 2
            let moveFactor = CGAffineTransform(translationX: posX, y: posY)

            var concat = preferredTransform.concatenating(scaleFactor).concatenating(moveFactor)

            if assetInfo.orientation == .down {
                let fixUpsideDown = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                concat = fixUpsideDown.concatenating(scaleFactor).concatenating(moveFactor)

            }
            instruction.setTransform(concat, at: .zero)
        }

        if isMirror {
            var transform: CGAffineTransform = CGAffineTransform(scaleX: -1.0, y: 1.0)
            transform = transform.translatedBy(x: -newSize.width, y: 0.0)
            instruction.setTransform(transform, at: .zero)
        }

        return instruction
    }

    private static func getSizeFromOrientation(
        newSize: CGSize, videoTrackPreferredTransform: CGAffineTransform
    ) -> CGSize {
        let orientation = self.orientationFromTransform(videoTrackPreferredTransform)

        var outputSize = newSize
        if !orientation.isPortrait {
            outputSize.width = newSize.height
            outputSize.height = newSize.width
        }
        return outputSize
    }

    private static func orientationFromTransform(_ transform: CGAffineTransform) -> (
        orientation: UIImage.Orientation, isPortrait: Bool
    ) {
        var assetOrientation = UIImage.Orientation.up
        var isPortrait = false
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .down
        }
        return (assetOrientation, isPortrait)
    }

    private static func createTempPath() -> URL {
        let fileName = "edited-video-\(UUID().uuidString).mp4"
        let tempURL = URL.temporaryDirectory.appending(path: fileName)
        FileManager.default.removeIfExists(for: tempURL)
        return tempURL
    }

    ///needed for simulator fix AVVideoCompositionCoreAnimationTool crash only in simulator
    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
    }

    private static func addImage(to layer: CALayer, watermark: UIImage, videoSize: CGSize) {
        let imageLayer = CALayer()
        let aspect: CGFloat = watermark.size.width / watermark.size.height
        let width = videoSize.width / 4
        let height = width / aspect
        imageLayer.frame = CGRect(
            x: width,
            y: 0,
            width: width,
            height: height)
        imageLayer.contents = watermark.cgImage
        layer.addSublayer(imageLayer)
    }

    private static func createTextLayer(
        with model: TextBox, size: CGSize, position: CGSize, ratio: Double, duration: Double
    ) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.string = model.text
        textLayer.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        textLayer.fontSize = model.fontSize * ratio
        textLayer.alignmentMode = .center
        textLayer.foregroundColor = UIColor(model.fontColor).cgColor
        let size = textLayer.preferredFrameSize()
        textLayer.frame = CGRect(
            x: position.width, y: position.height, width: size.width, height: size.height)
        textLayer.backgroundColor = UIColor(model.bgColor).cgColor

        addAnimation(to: textLayer, with: model.timeRange, duration: duration)

        return textLayer
    }

    static func convertSize(_ size: CGSize, fromFrame frameSize1: CGSize, toFrame frameSize2: CGSize)
        -> (size: CGSize, ratio: Double)
    {
        let widthRatio = frameSize2.width / frameSize1.width
        let heightRatio = frameSize2.height / frameSize1.height
        let ratio = max(widthRatio, heightRatio)
        let newSizeWidth = size.width * ratio
        let newSizeHeight = size.height * ratio

        let newSize = CGSize(
            width: (frameSize2.width / 2) + newSizeWidth, height: (frameSize2.height / 2) + -newSizeHeight
        )

        return (CGSize(width: newSize.width, height: newSize.height), ratio)
    }

    private static func addAnimation(
        to textLayer: CATextLayer, with timeRange: ClosedRange<Double>, duration: Double
    ) {

        if timeRange.lowerBound > 0 {
            let appearance = CABasicAnimation(keyPath: "opacity")
            appearance.fromValue = 0
            appearance.toValue = 1
            appearance.duration = 0.05
            appearance.beginTime = timeRange.lowerBound
            appearance.fillMode = .forwards
            appearance.isRemovedOnCompletion = false
            textLayer.add(appearance, forKey: "Appearance")
            textLayer.opacity = 0
        }

        if timeRange.upperBound < duration {
            let disappearance = CABasicAnimation(keyPath: "opacity")
            disappearance.fromValue = 1
            disappearance.toValue = 0
            disappearance.beginTime = timeRange.upperBound
            disappearance.duration = 0.05
            disappearance.fillMode = .forwards
            disappearance.isRemovedOnCompletion = false
            textLayer.add(disappearance, forKey: "Disappearance")
        }
    }
}

enum ExporterError: Error, LocalizedError {
    case unknow
    case cancelled
    case cannotCreateExportSession
    case failed

}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }

    var degTorad: Double {
        return self * .pi / 180
    }
}

//
//class ObservableExporter {
//
//    var progressTimer: Timer?
//    let session: AVAssetExportSession
//    public let progress: Binding<Double>
//    public var duration: TimeInterval?
//
//    init(session: AVAssetExportSession, progress: Binding<Double>) {
//        self.session = session
//        self.progress = progress
//    }
//
//    func export() async throws -> AVAssetExportSession.Status {
//        progressTimer = Timer(timeInterval: 0.1, repeats: true, block: { timer in
//            self.progress.wrappedValue = Double(self.session.progress)
//        })
//        RunLoop.main.add(progressTimer!, forMode: .common)
//        let startDate = Date()
//        await session.export()
//        progressTimer?.invalidate()
//        let endDate = Date()
//        duration = endDate.timeIntervalSince(startDate)
//        if let error = session.error {
//            throw error
//        } else {
//            return session.status
//        }
//    }
//}
