import CoreGraphics

struct LayoutEngine {
    nonisolated static func computeLayout(
        videoSize: CGSize,
        containerSize: CGSize,
        preset: ExportPreset,
        gravity: VideoGravity,
        preferredTransform: CGAffineTransform = .identity
    ) -> LayoutResult {
        let orientedBounds = orientedBounds(
            videoSize: videoSize,
            preferredTransform: preferredTransform
        )
        let orientedSize = orientedBounds.size
        let renderSize = preset.resolve(videoSize: orientedSize)
        let videoFrame = frame(
            for: orientedSize,
            in: containerSize,
            gravity: gravity
        )
        let renderFrame = frame(
            for: orientedSize,
            in: renderSize,
            gravity: gravity
        )

        let normalizedOrientation = preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -orientedBounds.minX,
                y: -orientedBounds.minY
            )
        )
        let renderScale = scaleFactor(
            contentSize: orientedSize,
            targetSize: renderSize,
            gravity: gravity
        )
        let transform = normalizedOrientation
            .concatenating(CGAffineTransform(scaleX: renderScale, y: renderScale))
            .concatenating(
                CGAffineTransform(
                    translationX: renderFrame.minX,
                    y: renderFrame.minY
                )
            )

        return LayoutResult(
            videoFrame: videoFrame,
            renderSize: renderSize,
            transform: transform
        )
    }
}

private extension LayoutEngine {
    nonisolated static func orientedBounds(
        videoSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> CGRect {
        CGRect(origin: .zero, size: videoSize)
            .applying(preferredTransform)
            .standardized
    }

    nonisolated static func frame(
        for contentSize: CGSize,
        in targetSize: CGSize,
        gravity: VideoGravity
    ) -> CGRect {
        let scale = scaleFactor(
            contentSize: contentSize,
            targetSize: targetSize,
            gravity: gravity
        )
        let width = contentSize.width * scale
        let height = contentSize.height * scale

        return CGRect(
            x: (targetSize.width - width) / 2,
            y: (targetSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    nonisolated static func scaleFactor(
        contentSize: CGSize,
        targetSize: CGSize,
        gravity: VideoGravity
    ) -> CGFloat {
        guard
            contentSize.width > 0,
            contentSize.height > 0,
            targetSize.width > 0,
            targetSize.height > 0
        else {
            return 0
        }

        let widthScale = targetSize.width / contentSize.width
        let heightScale = targetSize.height / contentSize.height

        switch gravity {
        case .fit:
            return min(widthScale, heightScale)
        case .fill:
            return max(widthScale, heightScale)
        }
    }
}
