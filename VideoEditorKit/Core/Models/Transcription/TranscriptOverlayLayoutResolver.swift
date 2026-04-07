//
//  TranscriptOverlayLayoutResolver.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import CoreGraphics
import Foundation

enum TranscriptOverlayLayoutResolver {

    private enum Constants {
        static let horizontalInset: CGFloat = 16
        static let minimumVerticalInset: CGFloat = 8
        static let verticalInsetRatio: CGFloat = 0.01
        static let minimumFontSize: CGFloat = 14
        static let textHorizontalPadding: CGFloat = 0
        static let minimumLineCount = 1
    }

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
        let availableWidth = max(videoWidth - (Constants.horizontalInset * 2), 0)
        let widthMultiplier: CGFloat
        let baseFontRatio: CGFloat

        switch selectedSize {
        case .small:
            widthMultiplier = 1
            baseFontRatio = 0.038
        case .medium:
            widthMultiplier = 1
            baseFontRatio = 0.05
        case .large:
            widthMultiplier = 1
            baseFontRatio = 0.064
        }

        let targetWidth = availableWidth * widthMultiplier
        let baseFontSize = max(videoHeight * baseFontRatio, Constants.minimumFontSize)
        let verticalInset = max(
            videoHeight * Constants.verticalInsetRatio,
            Constants.minimumVerticalInset
        )
        let maximumOverlayHeight = max(
            videoHeight - (verticalInset * 2),
            baseFontSize * 2.2
        )
        let fontSize = fittedFontSize(
            startingFrom: baseFontSize,
            for: text,
            targetWidth: targetWidth,
            maximumOverlayHeight: maximumOverlayHeight
        )
        let estimatedLineHeight = fontSize * 1.35
        let estimatedLineCount = estimatedLineCount(
            for: text,
            targetWidth: targetWidth,
            fontSize: fontSize
        )
        let verticalPadding = max(fontSize * 0.4, 8)
        let requestedOverlayHeight = estimatedLineHeight * CGFloat(estimatedLineCount) + verticalPadding
        let overlayHeight = min(requestedOverlayHeight, maximumOverlayHeight)
        let overlayY: CGFloat

        switch selectedPosition {
        case .top:
            overlayY = verticalInset
        case .center:
            overlayY = (videoHeight - overlayHeight) / 2
        case .bottom:
            overlayY = videoHeight - overlayHeight - verticalInset
        }

        let maximumOverlayY = max(videoHeight - overlayHeight - verticalInset, verticalInset)
        let clampedOverlayY = min(max(overlayY, verticalInset), maximumOverlayY)

        let overlayFrame = CGRect(
            x: max((videoWidth - targetWidth) / 2, Constants.horizontalInset),
            y: clampedOverlayY,
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

    static func resolvePreviewLayout(
        exportCanvasSize: CGSize,
        previewCanvasSize: CGSize,
        selectedPosition: TranscriptOverlayPosition,
        selectedSize: TranscriptOverlaySize,
        text: String
    ) -> Layout {
        guard exportCanvasSize.width > 0, exportCanvasSize.height > 0 else {
            return resolve(
                videoWidth: previewCanvasSize.width,
                videoHeight: previewCanvasSize.height,
                selectedPosition: selectedPosition,
                selectedSize: selectedSize,
                text: text
            )
        }

        let exportLayout = resolve(
            videoWidth: exportCanvasSize.width,
            videoHeight: exportCanvasSize.height,
            selectedPosition: selectedPosition,
            selectedSize: selectedSize,
            text: text
        )

        return scaled(
            exportLayout,
            from: exportCanvasSize,
            to: previewCanvasSize
        )
    }

    // MARK: - Private Methods

    private static func scaled(
        _ layout: Layout,
        from exportCanvasSize: CGSize,
        to previewCanvasSize: CGSize
    ) -> Layout {
        guard previewCanvasSize.width > 0, previewCanvasSize.height > 0 else {
            return Layout(
                overlayFrame: .zero,
                controlsAnchor: .zero,
                targetWidth: 0,
                fontSize: 0
            )
        }

        let widthScale = previewCanvasSize.width / max(exportCanvasSize.width, 1)
        let heightScale = previewCanvasSize.height / max(exportCanvasSize.height, 1)
        let fontScale = min(widthScale, heightScale)
        let overlayFrame = CGRect(
            x: layout.overlayFrame.minX * widthScale,
            y: layout.overlayFrame.minY * heightScale,
            width: layout.overlayFrame.width * widthScale,
            height: layout.overlayFrame.height * heightScale
        )

        return Layout(
            overlayFrame: overlayFrame,
            controlsAnchor: CGPoint(
                x: layout.controlsAnchor.x * widthScale,
                y: layout.controlsAnchor.y * heightScale
            ),
            targetWidth: layout.targetWidth * widthScale,
            fontSize: layout.fontSize * fontScale
        )
    }

    private static func estimatedLineCount(
        for text: String,
        targetWidth: CGFloat,
        fontSize: CGFloat
    ) -> Int {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else { return Constants.minimumLineCount }

        let effectiveTextWidth = max(targetWidth - Constants.textHorizontalPadding, fontSize)
        let estimatedCharacterWidth = max(fontSize * 0.58, 1)
        let charactersPerLine = max(
            Int((effectiveTextWidth / estimatedCharacterWidth).rounded(.down)),
            1
        )
        let explicitLineCount = max(trimmedText.components(separatedBy: .newlines).count, 1)
        let wrappedLineCount = Int(
            ceil(CGFloat(trimmedText.count) / CGFloat(charactersPerLine))
        )

        return max(explicitLineCount, wrappedLineCount, Constants.minimumLineCount)
    }

    private static func fittedFontSize(
        startingFrom baseFontSize: CGFloat,
        for text: String,
        targetWidth: CGFloat,
        maximumOverlayHeight: CGFloat
    ) -> CGFloat {
        var fontSize = baseFontSize
        var lineCount = estimatedLineCount(
            for: text,
            targetWidth: targetWidth,
            fontSize: fontSize
        )
        var verticalPadding = max(fontSize * 0.4, 8)
        var estimatedHeight = (fontSize * 1.35 * CGFloat(lineCount)) + verticalPadding

        guard estimatedHeight > maximumOverlayHeight else { return fontSize }

        let minimumFontSize = Constants.minimumFontSize

        while estimatedHeight > maximumOverlayHeight, fontSize > minimumFontSize {
            fontSize = max(fontSize - 1, minimumFontSize)
            lineCount = estimatedLineCount(
                for: text,
                targetWidth: targetWidth,
                fontSize: fontSize
            )
            verticalPadding = max(fontSize * 0.4, 8)
            estimatedHeight = (fontSize * 1.35 * CGFloat(lineCount)) + verticalPadding
        }

        return fontSize
    }

}
