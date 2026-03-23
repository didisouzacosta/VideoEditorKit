//
//  AVAssets+Ext.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import AVKit
import SwiftUI

extension AVAsset {
    
    struct TrimError: Error {
        let description: String
        let underlyingError: Error?
        
        init(_ description: String, underlyingError: Error? = nil) {
            self.description = "TrimVideo: " + description
            self.underlyingError = underlyingError
        }
    }
    
    func generateImage(at second: Double, compressionQuality: Double = 0.05) async -> UIImage? {
        let imgGenerator = AVAssetImageGenerator(asset: self)
        imgGenerator.appliesPreferredTrackTransform = true
        let requestedTime = CMTime(seconds: second, preferredTimescale: 600)

        return await withCheckedContinuation { continuation in
            imgGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: requestedTime)]) { _, image, _, result, _ in
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
    
    @MainActor
    func naturalSize() async -> CGSize? {
        guard let tracks = try? await loadTracks(withMediaType: .video) else { return nil }
        guard let track = tracks.first else { return nil }
        guard let size = try? await track.load(.naturalSize) else { return nil }
        return size
    }
    
    
    @MainActor
    func adjustVideoSize(to viewSize: CGSize) async -> CGSize? {
        
        
        guard let assetSize = await self.naturalSize() else { return nil }
        
        let videoRatio = assetSize.width / assetSize.height
        let isPortrait = assetSize.height > assetSize.width
        var videoSize = viewSize
        if isPortrait {
            videoSize = CGSize(width: videoSize.height * videoRatio, height: videoSize.height)
        } else {
            videoSize = CGSize(width: videoSize.width, height: videoSize.width / videoRatio)
        }
        return videoSize
    }
}
