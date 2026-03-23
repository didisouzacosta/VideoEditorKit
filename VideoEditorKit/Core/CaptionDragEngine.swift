import CoreGraphics

struct CaptionDragEngine {
    nonisolated static func reposition(
        _ caption: Caption,
        to displayPoint: CGPoint,
        displaySize: CGSize,
        renderSize: CGSize,
        safeFrame: CGRect
    ) -> Caption {
        guard displaySize.width > 0,
              displaySize.height > 0,
              renderSize.width > 0,
              renderSize.height > 0 else {
            return caption
        }

        var repositionedCaption = caption.beginningFreeformDrag(
            renderSize: renderSize,
            safeFrame: safeFrame
        )
        let renderPoint = CGPoint(
            x: scaledAxis(displayPoint.x, sourceDimension: displaySize.width, destinationDimension: renderSize.width),
            y: scaledAxis(displayPoint.y, sourceDimension: displaySize.height, destinationDimension: renderSize.height)
        )
        repositionedCaption.position = CaptionPositionResolver.normalizedPosition(
            for: renderPoint,
            in: renderSize
        )
        let resolvedPoint = CaptionPositionResolver.resolve(
            caption: repositionedCaption,
            renderSize: renderSize,
            safeFrame: safeFrame
        )

        repositionedCaption.position = CaptionPositionResolver.normalizedPosition(
            for: resolvedPoint,
            in: renderSize
        )
        return repositionedCaption
    }
}

private extension CaptionDragEngine {
    nonisolated static func scaledAxis(
        _ value: CGFloat,
        sourceDimension: CGFloat,
        destinationDimension: CGFloat
    ) -> CGFloat {
        (value / sourceDimension) * destinationDimension
    }
}
