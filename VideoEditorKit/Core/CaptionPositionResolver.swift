import CoreGraphics
import UIKit

struct CaptionPositionResolver {
    nonisolated static func resolve(
        caption: Caption,
        renderSize: CGSize,
        safeFrame: CGRect
    ) -> CGPoint {
        let frame = resolveFrame(
            caption: caption,
            renderSize: renderSize,
            safeFrame: safeFrame
        )

        return CGPoint(x: frame.midX, y: frame.midY)
    }

    nonisolated static func resolveFrame(
        caption: Caption,
        renderSize: CGSize,
        safeFrame: CGRect
    ) -> CGRect {
        let measuredSize = captionSize(
            for: caption,
            constrainedTo: safeFrame.size
        )
        let point = rawPoint(
            for: caption,
            renderSize: renderSize,
            safeFrame: safeFrame
        )
        let origin = clampedOrigin(
            for: point,
            size: measuredSize,
            safeFrame: safeFrame,
            anchorPoint: anchorPoint(for: caption.placementMode)
        )

        return CGRect(origin: origin, size: measuredSize)
    }

    nonisolated static func presetPoint(
        _ preset: CaptionPlacementPreset,
        in safeFrame: CGRect
    ) -> CGPoint {
        switch preset {
        case .top:
            CGPoint(x: safeFrame.midX, y: safeFrame.minY)
        case .middle:
            CGPoint(x: safeFrame.midX, y: safeFrame.midY)
        case .bottom:
            CGPoint(x: safeFrame.midX, y: safeFrame.maxY)
        }
    }

    nonisolated static func normalizedPosition(
        for point: CGPoint,
        in renderSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: normalizedAxis(point.x, dimension: renderSize.width),
            y: normalizedAxis(point.y, dimension: renderSize.height)
        )
    }
}

private extension CaptionPositionResolver {
    nonisolated static func rawPoint(
        for caption: Caption,
        renderSize: CGSize,
        safeFrame: CGRect
    ) -> CGPoint {
        switch caption.placementMode {
        case .freeform:
            CGPoint(
                x: caption.position.x * renderSize.width,
                y: caption.position.y * renderSize.height
            )
        case .preset(let preset):
            presetPoint(preset, in: safeFrame)
        }
    }

    nonisolated static func captionSize(
        for caption: Caption,
        constrainedTo availableSize: CGSize
    ) -> CGSize {
        let font = caption.style.resolvedFont()
        let padding = caption.style.padding
        let horizontalPadding = padding * 2
        let verticalPadding = padding * 2
        let maxTextWidth = max(availableSize.width - horizontalPadding, 1)
        let textBounds = (caption.text as NSString).boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).integral

        return CGSize(
            width: min(max(textBounds.width + horizontalPadding, 1), max(availableSize.width, 1)),
            height: min(max(textBounds.height + verticalPadding, 1), max(availableSize.height, 1))
        )
    }

    nonisolated static func clampedOrigin(
        for point: CGPoint,
        size: CGSize,
        safeFrame: CGRect,
        anchorPoint: CGPoint
    ) -> CGPoint {
        let rawX = point.x - (size.width * anchorPoint.x)
        let rawY = point.y - (size.height * anchorPoint.y)
        let maxX = max(safeFrame.minX, safeFrame.maxX - size.width)
        let maxY = max(safeFrame.minY, safeFrame.maxY - size.height)

        return CGPoint(
            x: min(max(rawX, safeFrame.minX), maxX),
            y: min(max(rawY, safeFrame.minY), maxY)
        )
    }

    nonisolated static func anchorPoint(
        for placementMode: CaptionPlacementMode
    ) -> CGPoint {
        switch placementMode {
        case .freeform:
            CGPoint(x: 0.5, y: 0.5)
        case .preset(.top):
            CGPoint(x: 0.5, y: 0)
        case .preset(.middle):
            CGPoint(x: 0.5, y: 0.5)
        case .preset(.bottom):
            CGPoint(x: 0.5, y: 1)
        }
    }

    nonisolated static func normalizedAxis(
        _ value: CGFloat,
        dimension: CGFloat
    ) -> CGFloat {
        guard dimension > 0 else {
            return 0
        }

        return min(max(value / dimension, 0), 1)
    }
}
