import AVFoundation
import CoreGraphics
import Foundation

struct AVFoundationVideoAssetLoader: VideoAssetLoading {
    nonisolated init() {}

    nonisolated func loadAsset(from sourceVideoURL: URL) async throws -> LoadedVideoAsset {
        guard
            sourceVideoURL.isFileURL,
            sourceVideoURL.path.isEmpty == false,
            FileManager.default.fileExists(atPath: sourceVideoURL.path)
        else {
            throw VideoEditorError.invalidAsset
        }

        let asset = AVURLAsset(url: sourceVideoURL)

        do {
            let duration = try await asset.load(.duration).seconds
            guard duration.isFinite, duration >= 0 else {
                throw VideoEditorError.invalidVideoDuration
            }

            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw VideoEditorError.invalidAsset
            }

            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)
            let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
            let presentationSize = orientedBounds(
                videoSize: naturalSize,
                preferredTransform: preferredTransform
            ).size

            return LoadedVideoAsset(
                asset: asset,
                duration: duration,
                naturalSize: naturalSize,
                preferredTransform: preferredTransform,
                presentationSize: presentationSize,
                nominalFrameRate: nominalFrameRate
            )
        } catch let error as VideoEditorError {
            throw error
        } catch {
            throw VideoEditorError.invalidAsset
        }
    }
}

private extension AVFoundationVideoAssetLoader {
    nonisolated func orientedBounds(
        videoSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> CGRect {
        CGRect(origin: .zero, size: videoSize)
            .applying(preferredTransform)
            .standardized
    }
}
