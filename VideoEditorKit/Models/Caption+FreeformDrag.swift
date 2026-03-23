import CoreGraphics

extension Caption {
    nonisolated func beginningFreeformDrag(
        renderSize: CGSize,
        safeFrame: CGRect
    ) -> Caption {
        let resolvedPoint = CaptionPositionResolver.resolve(
            caption: self,
            renderSize: renderSize,
            safeFrame: safeFrame
        )

        var caption = self
        caption.position = CaptionPositionResolver.normalizedPosition(
            for: resolvedPoint,
            in: renderSize
        )
        caption.placementMode = .freeform
        return caption
    }
}
