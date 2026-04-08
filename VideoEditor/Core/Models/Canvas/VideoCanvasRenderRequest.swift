//
//  VideoCanvasRenderRequest.swift
//  VideoEditorKit
//
//  Created by Codex on 31.03.2026.
//

import CoreGraphics
import Foundation

struct VideoCanvasSourceDescriptor: Equatable, Sendable {

    // MARK: - Public Properties

    let naturalSize: CGSize
    let preferredTransform: CGAffineTransform
    let userRotationDegrees: Double
    let isMirrored: Bool

    var resolvedPresentationSize: CGSize {
        let transformedBounds = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
            .standardized
        let resolvedSize = CGSize(
            width: abs(transformedBounds.width),
            height: abs(transformedBounds.height)
        )

        guard resolvedSize.width > 0, resolvedSize.height > 0 else {
            return naturalSize
        }

        return resolvedSize
    }

}

struct VideoCanvasResolvedPreset: Equatable, Sendable {

    // MARK: - Public Properties

    let preset: VideoCanvasPreset
    let exportSize: CGSize

}

struct VideoCanvasRenderRequest: Equatable, Sendable {

    // MARK: - Public Properties

    let source: VideoCanvasSourceDescriptor
    let snapshot: VideoCanvasSnapshot
    let resolvedPreset: VideoCanvasResolvedPreset

}

struct VideoCanvasExportMapping: Equatable, Sendable {

    // MARK: - Public Properties

    let renderSize: CGSize
    let orientedSourceSize: CGSize
    let aspectFillScale: CGFloat
    let contentTransform: CGAffineTransform
    let totalRotationRadians: CGFloat

}
