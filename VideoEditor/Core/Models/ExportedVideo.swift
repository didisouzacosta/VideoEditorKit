//
//  ExportedVideo.swift
//  VideoEditorKit
//
//  Created by Adriano Costa on 27.03.2026.
//

import AVFoundation
import CoreGraphics
import Foundation

struct ExportedVideo: Equatable, Sendable {

    // MARK: - Public Properties

    let url: URL
    let width: CGFloat
    let height: CGFloat
    let duration: Double
    let fileSize: Int64

    var aspectRatio: CGFloat {
        guard width > 0, height > 0 else { return 1 }
        return width / height
    }

    // MARK: - Initializer

    init(
        _ url: URL,
        width: CGFloat,
        height: CGFloat,
        duration: Double,
        fileSize: Int64
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.duration = duration
        self.fileSize = fileSize
    }

    // MARK: - Public Methods

    static func load(from url: URL) async -> ExportedVideo {
        let asset = AVURLAsset(url: url)
        let presentationSize = await asset.presentationSize() ?? .zero
        let duration = (try? await asset.load(.duration).seconds) ?? .zero
        let fileSize = resolvedFileSize(for: url)

        return ExportedVideo(
            url,
            width: max(presentationSize.width, 0),
            height: max(presentationSize.height, 0),
            duration: max(duration, 0),
            fileSize: max(fileSize, 0)
        )
    }

    // MARK: - Private Methods

    private static func resolvedFileSize(for url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path())
        let sizeValue = attributes?[.size] as? NSNumber
        return sizeValue?.int64Value ?? 0
    }

}
