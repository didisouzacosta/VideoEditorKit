import CoreGraphics

struct CaptionPositionResolver {
    nonisolated static func resolve(
        caption: Caption,
        renderSize: CGSize,
        safeFrame: CGRect
    ) -> CGPoint {
        switch caption.placementMode {
        case .freeform:
            let absolutePoint = CGPoint(
                x: caption.position.x * renderSize.width,
                y: caption.position.y * renderSize.height
            )

            return clamped(absolutePoint, to: safeFrame)
        case .preset(let preset):
            return presetPoint(preset, in: safeFrame)
        }
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
    nonisolated static func clamped(_ point: CGPoint, to safeFrame: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, safeFrame.minX), safeFrame.maxX),
            y: min(max(point.y, safeFrame.minY), safeFrame.maxY)
        )
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
