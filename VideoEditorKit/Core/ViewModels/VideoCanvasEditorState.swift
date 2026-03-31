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
    ) async -> VideoCanvasRenderRequest {
        await mappingActor.makeRenderRequest(
            source: source,
            snapshot: snapshot()
        )
    }

    func previewLayout(
        source: VideoCanvasSourceDescriptor,
        availableSize: CGSize
    ) async -> VideoCanvasLayout {
        let request = await makeRenderRequest(source: source)
        return await mappingActor.makePreviewLayout(
            request: request,
            availableSize: availableSize
        )
    }

    func exportMapping(
        source: VideoCanvasSourceDescriptor
    ) async -> VideoCanvasExportMapping {
        let request = await makeRenderRequest(source: source)
        return await mappingActor.makeExportMapping(request: request)
    }

    func dragTransform(
        from baseline: VideoCanvasTransform,
        translation: CGSize,
        previewCanvasSize: CGSize
    ) async -> VideoCanvasTransform {
        await mappingActor.dragTransform(
            from: baseline,
            translation: translation,
            previewCanvasSize: previewCanvasSize
        )
    }

    func magnifiedTransform(
        from baseline: VideoCanvasTransform,
        magnification: CGFloat
    ) async -> VideoCanvasTransform {
        await mappingActor.magnifiedTransform(
            from: baseline,
            magnification: magnification
        )
    }

    func rotatedTransform(
        from baseline: VideoCanvasTransform,
        rotation: Angle
    ) async -> VideoCanvasTransform {
        await mappingActor.rotatedTransform(
            from: baseline,
            rotation: rotation
        )
    }

    func snapshotTransform(
        fromLegacyFreeformRect freeformRect: VideoEditingConfiguration.FreeformRect?,
        referenceSize: CGSize
    ) async -> VideoCanvasTransform {
        let request = await makeRenderRequest(
            source: .init(
                naturalSize: referenceSize,
                preferredTransform: .identity,
                userRotationDegrees: 0,
                isMirrored: false
            )
        )

        return await mappingActor.snapshotTransform(
            fromLegacyFreeformRect: freeformRect,
            referenceSize: referenceSize,
            exportSize: request.resolvedPreset.exportSize
        )
    }

}
