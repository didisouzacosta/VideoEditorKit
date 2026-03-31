//
//  VideoCanvasMappingActor.swift
//  VideoEditorKit
//
//  Created by Codex on 31.03.2026.
//

import CoreGraphics
import Foundation
import SwiftUI

actor VideoCanvasMappingActor {

    // MARK: - Public Methods

    func makeRenderRequest(
        source: VideoCanvasSourceDescriptor,
        snapshot: VideoCanvasSnapshot
    ) -> VideoCanvasRenderRequest {
        let resolvedPreset = resolvePreset(
            snapshot.preset,
            naturalSize: source.resolvedPresentationSize,
            freeCanvasSize: snapshot.freeCanvasSize
        )

        return VideoCanvasRenderRequest(
            source: source,
            snapshot: snapshot,
            resolvedPreset: resolvedPreset
        )
    }

    func resolvePreset(
        _ preset: VideoCanvasPreset,
        naturalSize: CGSize,
        freeCanvasSize: CGSize
    ) -> VideoCanvasResolvedPreset {
        VideoCanvasResolvedPreset(
            preset: preset,
            exportSize: evenPixelSize(
                for: preset.resolvedExportSize(
                    naturalSize: naturalSize,
                    freeCanvasSize: freeCanvasSize
                )
            )
        )
    }

    func makePreviewLayout(
        request: VideoCanvasRenderRequest,
        availableSize: CGSize
    ) -> VideoCanvasLayout {
        let exportMapping = makeExportMapping(request: request)
        let previewCanvasSize = fittedAspectSize(
            exportMapping.renderSize,
            in: availableSize
        )
        let previewScale = scaleFactor(
            from: exportMapping.renderSize,
            to: previewCanvasSize
        )
        let normalizedOffset = request.snapshot.transform.normalizedOffset

        return VideoCanvasLayout(
            previewCanvasSize: previewCanvasSize,
            exportCanvasSize: exportMapping.renderSize,
            previewScale: previewScale,
            contentBaseSize: CGSize(
                width: exportMapping.orientedSourceSize.width * previewScale,
                height: exportMapping.orientedSourceSize.height * previewScale
            ),
            contentScale: exportMapping.aspectFillScale,
            contentCenter: CGPoint(
                x: previewCanvasSize.width / 2 + normalizedOffset.x * previewCanvasSize.width,
                y: previewCanvasSize.height / 2 + normalizedOffset.y * previewCanvasSize.height
            ),
            totalRotationRadians: exportMapping.totalRotationRadians,
            isMirrored: request.source.isMirrored
        )
    }

    func makeExportMapping(
        request: VideoCanvasRenderRequest
    ) -> VideoCanvasExportMapping {
        let normalizedTransform = normalizedPreferredTransform(for: request.source)
        let orientedSourceSize = request.source.resolvedPresentationSize
        let renderSize = request.resolvedPreset.exportSize
        let aspectFillScale =
            max(
                renderSize.width / max(orientedSourceSize.width, 1),
                renderSize.height / max(orientedSourceSize.height, 1)
            ) * request.snapshot.transform.zoom
        let contentOffset = CGPoint(
            x: request.snapshot.transform.normalizedOffset.x * renderSize.width,
            y: request.snapshot.transform.normalizedOffset.y * renderSize.height
        )
        let totalRotationRadians =
            CGFloat(request.source.userRotationDegrees) * .pi / 180
            + request.snapshot.transform.rotationRadians

        let centeredTransform = CGAffineTransform(
            translationX: -orientedSourceSize.width / 2,
            y: -orientedSourceSize.height / 2
        )
        .concatenating(
            CGAffineTransform(scaleX: aspectFillScale, y: aspectFillScale)
        )
        .concatenating(
            request.source.isMirrored
                ? CGAffineTransform(scaleX: -1, y: 1)
                : .identity
        )
        .concatenating(
            CGAffineTransform(rotationAngle: totalRotationRadians)
        )
        .concatenating(
            CGAffineTransform(
                translationX: renderSize.width / 2 + contentOffset.x,
                y: renderSize.height / 2 + contentOffset.y
            )
        )

        return VideoCanvasExportMapping(
            renderSize: renderSize,
            orientedSourceSize: orientedSourceSize,
            aspectFillScale: aspectFillScale,
            contentTransform: normalizedTransform.concatenating(centeredTransform),
            totalRotationRadians: totalRotationRadians
        )
    }

    func dragTransform(
        from baseline: VideoCanvasTransform,
        translation: CGSize,
        previewCanvasSize: CGSize
    ) -> VideoCanvasTransform {
        guard previewCanvasSize.width > 0, previewCanvasSize.height > 0 else {
            return baseline
        }

        var nextTransform = baseline
        nextTransform.normalizedOffset.x =
            baseline.normalizedOffset.x + translation.width / previewCanvasSize.width
        nextTransform.normalizedOffset.y =
            baseline.normalizedOffset.y + translation.height / previewCanvasSize.height

        return nextTransform
    }

    func magnifiedTransform(
        from baseline: VideoCanvasTransform,
        magnification: CGFloat
    ) -> VideoCanvasTransform {
        guard magnification.isFinite, magnification > 0 else { return baseline }

        var nextTransform = baseline
        nextTransform.zoom = min(max(baseline.zoom * magnification, 0.25), 8)
        return nextTransform
    }

    func rotatedTransform(
        from baseline: VideoCanvasTransform,
        rotation: Angle
    ) -> VideoCanvasTransform {
        var nextTransform = baseline
        nextTransform.rotationRadians = baseline.rotationRadians + rotation.radians
        return nextTransform
    }

    func snapshotTransform(
        fromLegacyFreeformRect freeformRect: VideoEditingConfiguration.FreeformRect?,
        referenceSize: CGSize,
        exportSize: CGSize
    ) -> VideoCanvasTransform {
        guard
            let freeformRect,
            let geometry = VideoCropPreviewLayout.resolvedGeometry(
                freeformRect: freeformRect,
                in: referenceSize
            )
        else {
            return .identity
        }

        let visibleRect = geometry.sourceRect
        let currentScale = max(
            exportSize.width / max(visibleRect.width, 1),
            exportSize.height / max(visibleRect.height, 1)
        )
        let baseScale = max(
            exportSize.width / max(referenceSize.width, 1),
            exportSize.height / max(referenceSize.height, 1)
        )
        let contentSize = CGSize(
            width: referenceSize.width * currentScale,
            height: referenceSize.height * currentScale
        )
        let contentOrigin = CGPoint(
            x: -visibleRect.minX * currentScale,
            y: -visibleRect.minY * currentScale
        )
        let contentCenter = CGPoint(
            x: contentOrigin.x + contentSize.width / 2,
            y: contentOrigin.y + contentSize.height / 2
        )
        let normalizedOffset = CGPoint(
            x: (contentCenter.x - exportSize.width / 2) / max(exportSize.width, 1),
            y: (contentCenter.y - exportSize.height / 2) / max(exportSize.height, 1)
        )

        return VideoCanvasTransform(
            normalizedOffset: normalizedOffset,
            zoom: currentScale / max(baseScale, 0.0001),
            rotationRadians: 0
        )
    }

    // MARK: - Private Methods

    private func normalizedPreferredTransform(
        for source: VideoCanvasSourceDescriptor
    ) -> CGAffineTransform {
        let transformedBounds = CGRect(origin: .zero, size: source.naturalSize)
            .applying(source.preferredTransform)
            .standardized

        return source.preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -transformedBounds.minX,
                y: -transformedBounds.minY
            )
        )
    }

    private func fittedAspectSize(
        _ size: CGSize,
        in bounds: CGSize
    ) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        guard bounds.width > 0, bounds.height > 0 else { return .zero }

        let widthScale = bounds.width / size.width
        let heightScale = bounds.height / size.height
        let scale = min(widthScale, heightScale)

        return CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    private func scaleFactor(
        from originalSize: CGSize,
        to fittedSize: CGSize
    ) -> CGFloat {
        guard originalSize.width > 0, originalSize.height > 0 else { return 1 }
        guard fittedSize.width > 0, fittedSize.height > 0 else { return 1 }

        return min(
            fittedSize.width / originalSize.width,
            fittedSize.height / originalSize.height
        )
    }

    private func evenPixelSize(
        for size: CGSize
    ) -> CGSize {
        CGSize(
            width: max(round(size.width / 2) * 2, 2),
            height: max(round(size.height / 2) * 2, 2)
        )
    }

}
