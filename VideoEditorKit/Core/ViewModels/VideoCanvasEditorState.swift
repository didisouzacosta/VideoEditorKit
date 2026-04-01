//
//  VideoCanvasEditorState.swift
//  VideoEditorKit
//
//  Created by Codex on 31.03.2026.
//

import CoreGraphics
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class VideoCanvasEditorState {

    // MARK: - Public Properties

    var preset: VideoCanvasPreset = .original
    var freeCanvasSize = CGSize(width: 1080, height: 1080)
    var transform: VideoCanvasTransform = .identity
    var showsSafeAreaOverlay = false

    var isIdentity: Bool {
        snapshot().isIdentity
    }

    var shouldShowResetButton: Bool {
        transform.shouldShowResetButton
    }

    // MARK: - Private Properties

    private let mappingActor = VideoCanvasMappingActor()

    // MARK: - Public Methods

    func snapshot() -> VideoCanvasSnapshot {
        VideoCanvasSnapshot(
            preset: preset,
            freeCanvasSize: freeCanvasSize,
            transform: transform,
            showsSafeAreaOverlay: showsSafeAreaOverlay
        )
    }

    func restore(_ snapshot: VideoCanvasSnapshot) {
        preset = snapshot.preset
        freeCanvasSize = snapshot.freeCanvasSize
        transform = snapshot.transform
        showsSafeAreaOverlay = snapshot.showsSafeAreaOverlay
    }

    func resetTransform() {
        transform = .identity
    }

    func makeRenderRequest(
        source: VideoCanvasSourceDescriptor
    ) -> VideoCanvasRenderRequest {
        mappingActor.makeRenderRequest(
            source: source,
            snapshot: snapshot()
        )
    }

    func previewLayout(
        source: VideoCanvasSourceDescriptor,
        availableSize: CGSize
    ) -> VideoCanvasLayout {
        let request = makeRenderRequest(source: source)
        return mappingActor.makePreviewLayout(
            request: request,
            availableSize: availableSize
        )
    }

    func exportMapping(
        source: VideoCanvasSourceDescriptor
    ) -> VideoCanvasExportMapping {
        let request = makeRenderRequest(source: source)
        return mappingActor.makeExportMapping(request: request)
    }

    func dragTransform(
        from baseline: VideoCanvasTransform,
        translation: CGSize,
        previewCanvasSize: CGSize
    ) -> VideoCanvasTransform {
        mappingActor.dragTransform(
            from: baseline,
            translation: translation,
            previewCanvasSize: previewCanvasSize
        )
    }

    func magnifiedTransform(
        from baseline: VideoCanvasTransform,
        magnification: CGFloat,
        anchor: CGPoint,
        previewCanvasSize: CGSize
    ) -> VideoCanvasTransform {
        mappingActor.magnifiedTransform(
            from: baseline,
            magnification: magnification,
            anchor: anchor,
            previewCanvasSize: previewCanvasSize
        )
    }

    func rotatedTransform(
        from baseline: VideoCanvasTransform,
        rotation: Angle
    ) -> VideoCanvasTransform {
        mappingActor.rotatedTransform(
            from: baseline,
            rotation: rotation
        )
    }

    func snapshotTransform(
        fromLegacyFreeformRect freeformRect: VideoEditingConfiguration.FreeformRect?,
        referenceSize: CGSize
    ) -> VideoCanvasTransform {
        let request = makeRenderRequest(
            source: .init(
                naturalSize: referenceSize,
                preferredTransform: .identity,
                userRotationDegrees: 0,
                isMirrored: false
            )
        )

        return mappingActor.snapshotTransform(
            fromLegacyFreeformRect: freeformRect,
            referenceSize: referenceSize,
            exportSize: request.resolvedPreset.exportSize
        )
    }

}
