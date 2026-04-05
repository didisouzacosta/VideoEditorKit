//
//  TranscriptOverlayLayoutResolver.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import CoreGraphics
import Foundation

enum TranscriptOverlayLayoutResolver {

    struct Layout: Equatable {

        // MARK: - Public Properties

        let overlayFrame: CGRect
        let controlsAnchor: CGPoint
        let targetWidth: CGFloat
        let fontSize: CGFloat

    }

    // MARK: - Public Methods

    static func resolve(
        videoWidth: CGFloat,
        videoHeight: CGFloat,
        selectedPosition: TranscriptOverlayPosition,
        selectedSize: TranscriptOverlaySize,
        text: String
    ) -> Layout {
        let horizontalInset: CGFloat = 32
        let availableWidth = max(videoWidth - (horizontalInset * 2), 0)
        let widthMultiplier: CGFloat
        let baseFontRatio: CGFloat

        switch selectedSize {
        case .small:
            widthMultiplier = 0.5
            baseFontRatio = 0.038
        case .medium:
            widthMultiplier = 0.75
            baseFontRatio = 0.05
        case .large:
            widthMultiplier = 1
            baseFontRatio = 0.064
        }

        let targetWidth = availableWidth * widthMultiplier
        let baseFontSize = max(videoHeight * baseFontRatio, 14)
        let normalizedCharacterCount = max(CGFloat(text.count), 12)
        let widthConstrainedFontSize = max((targetWidth / normalizedCharacterCount) * 2.1, 14)
        let fontSize = min(baseFontSize, widthConstrainedFontSize)
        let estimatedLineHeight = fontSize * 1.35
        let overlayHeight = max(estimatedLineHeight * 2.2, fontSize * 1.8)
        let centerY: CGFloat

        switch selectedPosition {
        case .top:
            centerY = max(videoHeight * 0.18, overlayHeight / 2 + 20)
        case .center:
            centerY = videoHeight * 0.5
        case .bottom:
            centerY = min(videoHeight * 0.82, videoHeight - overlayHeight / 2 - 20)
        }

        let overlayFrame = CGRect(
            x: max((videoWidth - targetWidth) / 2, horizontalInset),
            y: centerY - (overlayHeight / 2),
            width: targetWidth,
            height: overlayHeight
        )
        let controlsY = max(overlayFrame.minY - 34, 14)
        let fallbackControlsY = min(overlayFrame.maxY + 34, videoHeight - 14)
        let preferredControlsY = overlayFrame.minY > 52 ? controlsY : fallbackControlsY

        return Layout(
            overlayFrame: overlayFrame,
            controlsAnchor: CGPoint(
                x: overlayFrame.midX,
                y: preferredControlsY
            ),
            targetWidth: targetWidth,
            fontSize: fontSize
        )
    }

}
