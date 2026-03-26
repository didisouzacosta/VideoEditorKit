//
//  AVAssets+Ext.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import Foundation
import SwiftUI

extension AVAsset {

    // MARK: - Public Properties

    struct TrimError: Error {

        let description: String
        let underlyingError: Error?

        init(_ description: String, underlyingError: Error? = nil) {
            self.description = "TrimVideo: " + description
            self.underlyingError = underlyingError
        }

    }

    // MARK: - Public Methods

    @MainActor
    func generateImage(at second: Double, compressionQuality: Double = 0.05) async -> UIImage? {
        let imgGenerator = AVAssetImageGenerator(asset: self)
        imgGenerator.appliesPreferredTrackTransform = true
        let requestedTime = CMTime(seconds: second, preferredTimescale: 600)

        return await withCheckedContinuation { continuation in
            imgGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: requestedTime)]) {
                _, image, _, result, _ in
                guard result == .succeeded, let image else {
                    continuation.resume(returning: nil)
                    return
                }

                let uiImage = UIImage(cgImage: image)
                guard let imageData = uiImage.jpegData(compressionQuality: compressionQuality) else {
                    continuation.resume(returning: uiImage)
                    return
                }

                continuation.resume(returning: UIImage(data: imageData) ?? uiImage)
            }
        }
    }

    func naturalSize() async -> CGSize? {
        guard let tracks = try? await loadTracks(withMediaType: .video) else { return nil }
        guard let track = tracks.first else { return nil }
        guard let size = try? await track.load(.naturalSize) else { return nil }
        return size
    }

    func presentationSize() async -> CGSize? {
        guard let tracks = try? await loadTracks(withMediaType: .video) else { return nil }
        guard let track = tracks.first else { return nil }
        guard let naturalSize = try? await track.load(.naturalSize) else { return nil }
        guard let preferredTransform = try? await track.load(.preferredTransform) else { return nil }

        let transformedSize = naturalSize.applying(preferredTransform)
        let resolvedSize = CGSize(
            width: abs(transformedSize.width),
            height: abs(transformedSize.height)
        )

        guard resolvedSize.width > 0, resolvedSize.height > 0 else {
            return naturalSize
        }

        return resolvedSize
    }

    func adjustVideoSize(to viewSize: CGSize, rotationAngle: Double = 0) async -> CGSize? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        guard let assetSize = await self.presentationSize() else { return nil }

        let normalizedAngle = Int(rotationAngle) % 180
        let fittedAssetSize: CGSize
        if normalizedAngle == 0 {
            fittedAssetSize = assetSize
        } else {
            fittedAssetSize = CGSize(width: assetSize.height, height: assetSize.width)
        }

        let widthScale = viewSize.width / fittedAssetSize.width
        let heightScale = viewSize.height / fittedAssetSize.height
        let scale = min(widthScale, heightScale)

        return CGSize(
            width: fittedAssetSize.width * scale,
            height: fittedAssetSize.height * scale
        )
    }

}
