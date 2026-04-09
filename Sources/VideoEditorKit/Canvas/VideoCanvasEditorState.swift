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

@available(iOS 17.0, *)
@MainActor
@Observable
public final class VideoCanvasEditorState {

    // MARK: - Public Properties

    public var preset: VideoCanvasPreset = .original
    public var freeCanvasSize = CGSize(width: 1080, height: 1080)
    public var transform: VideoCanvasTransform = .identity
    public var showsSafeAreaOverlay = false

    public var isIdentity: Bool {
        snapshot().isIdentity
    }

    public var shouldShowResetButton: Bool {
        transform.shouldShowResetButton
    }

    // MARK: - Private Properties

    private let mappingActor = VideoCanvasMappingActor()

    // MARK: - Public Methods

    public init() {}

    public func snapshot() -> VideoCanvasSnapshot {
        snapshot(with: transform)
    }

    public func snapshot(
        with transform: VideoCanvasTransform
    ) -> VideoCanvasSnapshot {
        VideoCanvasSnapshot(
            preset: preset,
            freeCanvasSize: freeCanvasSize,
            transform: transform,
            showsSafeAreaOverlay: showsSafeAreaOverlay
        )
    }

    public func restore(_ snapshot: VideoCanvasSnapshot) {
        preset = snapshot.preset
        freeCanvasSize = snapshot.freeCanvasSize
        transform = snapshot.transform
        showsSafeAreaOverlay = snapshot.showsSafeAreaOverlay
    }

    public func resetTransform() {
        transform = .identity
    }

    public func makeRenderRequest(
        source: VideoCanvasSourceDescriptor,
        canvasSnapshot: VideoCanvasSnapshot? = nil
    ) -> VideoCanvasRenderRequest {
        mappingActor.makeRenderRequest(
            source: source,
            snapshot: canvasSnapshot ?? snapshot()
        )
    }

    public func previewLayout(
        source: VideoCanvasSourceDescriptor,
        availableSize: CGSize,
        canvasSnapshot: VideoCanvasSnapshot? = nil
    ) -> VideoCanvasLayout {
        let request = makeRenderRequest(
            source: source,
            canvasSnapshot: canvasSnapshot
        )
        return mappingActor.makePreviewLayout(
            request: request,
            availableSize: availableSize
        )
    }

    public func exportMapping(
        source: VideoCanvasSourceDescriptor
    ) -> VideoCanvasExportMapping {
        let request = makeRenderRequest(source: source)
        return mappingActor.makeExportMapping(request: request)
    }

    public func dragTransform(
        from baseline: VideoCanvasTransform,
        translation: CGSize,
        previewCanvasSize: CGSize,
        source: VideoCanvasSourceDescriptor
    ) -> VideoCanvasTransform {
        mappingActor.dragTransform(
            from: baseline,
            translation: translation,
            previewCanvasSize: previewCanvasSize,
            source: source,
            preset: preset,
            freeCanvasSize: freeCanvasSize
        )
    }

    public func magnifiedTransform(
        from baseline: VideoCanvasTransform,
        magnification: CGFloat,
        anchor: CGPoint,
        previewCanvasSize: CGSize,
        source: VideoCanvasSourceDescriptor
    ) -> VideoCanvasTransform {
        mappingActor.magnifiedTransform(
            from: baseline,
            magnification: magnification,
            anchor: anchor,
            previewCanvasSize: previewCanvasSize,
            source: source,
            preset: preset,
            freeCanvasSize: freeCanvasSize
        )
    }

    public func rotatedTransform(
        from baseline: VideoCanvasTransform,
        rotation: Angle,
        source: VideoCanvasSourceDescriptor
    ) -> VideoCanvasTransform {
        mappingActor.rotatedTransform(
            from: baseline,
            rotation: rotation,
            source: source,
            preset: preset,
            freeCanvasSize: freeCanvasSize
        )
    }

    public func interactiveTransform(
        from baseline: VideoCanvasTransform,
        translation: CGSize,
        magnification: CGFloat,
        anchor: CGPoint,
        rotation: Angle,
        previewCanvasSize: CGSize,
        source: VideoCanvasSourceDescriptor
    ) -> VideoCanvasTransform {
        mappingActor.interactiveTransform(
            from: baseline,
            translation: translation,
            magnification: magnification,
            anchor: anchor,
            rotation: rotation,
            previewCanvasSize: previewCanvasSize,
            source: source,
            preset: preset,
            freeCanvasSize: freeCanvasSize
        )
    }

    public func snapshotTransform(
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
