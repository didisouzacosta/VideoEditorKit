import AVKit
import Foundation
import SwiftUI

extension AVAsset {

    // MARK: - Public Methods

    func generateImage(
        at second: Double,
        maximumSize: CGSize = .zero,
        requiresExactFrame: Bool = false
    ) async -> UIImage? {
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.appliesPreferredTrackTransform = true

        if requiresExactFrame {
            imageGenerator.requestedTimeToleranceBefore = .zero
            imageGenerator.requestedTimeToleranceAfter = .zero
        }

        if maximumSize != .zero {
            imageGenerator.maximumSize = maximumSize
        }

        let requestedTime = CMTime(seconds: max(second, .zero), preferredTimescale: 600)

        return await withCheckedContinuation { continuation in
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: requestedTime)]) {
                _, image, _, result, _ in
                if result == .succeeded, let image {
                    continuation.resume(returning: UIImage(cgImage: image))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

}
