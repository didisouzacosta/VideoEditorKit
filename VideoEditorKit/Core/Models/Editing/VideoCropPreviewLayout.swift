//
//  VideoCropPreviewLayout.swift
//  VideoEditorKit
//
//  Created by Codex on 30.03.2026.
//

import CoreGraphics
import Foundation

struct VideoCropPreviewLayout: Equatable, Sendable {

    // MARK: - Public Properties

    let viewportRect: CGRect
    let contentScale: CGFloat
    let contentOffset: CGSize

    // MARK: - Initializer

    init?(
        freeformRect: VideoEditingConfiguration.FreeformRect?,
        in referenceSize: CGSize
    ) {
        guard
            let currentRect = Self.decodedRect(
                from: freeformRect,
                in: referenceSize
            ),
            let viewportFreeformRect = VideoCropFormatPreset.resetRect(
                matching: freeformRect,
                in: referenceSize
            ),
            let viewportRect = Self.decodedRect(
                from: viewportFreeformRect,
                in: referenceSize
            ),
            currentRect.width > 0,
            currentRect.height > 0,
            viewportRect.width > 0,
            viewportRect.height > 0
        else { return nil }

        let contentScale = max(
            viewportRect.width / currentRect.width,
            viewportRect.height / currentRect.height
        )

        self.viewportRect = viewportRect
        self.contentScale = contentScale
        self.contentOffset = CGSize(
            width: viewportRect.minX - currentRect.minX * contentScale,
            height: viewportRect.minY - currentRect.minY * contentScale
        )
    }

    // MARK: - Public Methods

    func sourceTranslation(for gestureTranslation: CGSize) -> CGSize {
        guard contentScale > 0 else { return .zero }

        return CGSize(
            width: -gestureTranslation.width / contentScale,
            height: -gestureTranslation.height / contentScale
        )
    }

    // MARK: - Private Methods

    private static func decodedRect(
        from freeformRect: VideoEditingConfiguration.FreeformRect?,
        in referenceSize: CGSize
    ) -> CGRect? {
        guard let freeformRect else { return nil }
        guard referenceSize.width > 0, referenceSize.height > 0 else { return nil }

        return CGRect(
            x: freeformRect.x * referenceSize.width,
            y: freeformRect.y * referenceSize.height,
            width: freeformRect.width * referenceSize.width,
            height: freeformRect.height * referenceSize.height
        )
    }

}
