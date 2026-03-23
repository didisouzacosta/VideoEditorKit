import AVFoundation
import CoreGraphics

struct LoadedVideoAsset: @unchecked Sendable {
    nonisolated(unsafe) let asset: AVAsset
    nonisolated let duration: Double
    nonisolated let naturalSize: CGSize
    nonisolated let preferredTransform: CGAffineTransform
    nonisolated let presentationSize: CGSize
    nonisolated let nominalFrameRate: Float

    nonisolated init(
        asset: AVAsset,
        duration: Double,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        presentationSize: CGSize,
        nominalFrameRate: Float
    ) {
        self.asset = asset
        self.duration = duration
        self.naturalSize = naturalSize
        self.preferredTransform = preferredTransform
        self.presentationSize = presentationSize
        self.nominalFrameRate = nominalFrameRate
    }
}
