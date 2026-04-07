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
        static let uniformInset: CGFloat = 16
        static let minimumFontSize: CGFloat = 14
        static let textHorizontalInset: CGFloat = 12
        static let textVerticalInset: CGFloat = 16
        static let defaultStyleID =
            UUID(uuidString: "E5A04D11-329A-4C8E-B266-1E6A60A6F9F9")
            ?? UUID()
    }

    struct Layout: Equatable {

        // MARK: - Public Properties

        let overlayFrame: CGRect
        let textFrame: CGRect
        let controlsAnchor: CGPoint
        let targetWidth: CGFloat
        let fontSize: CGFloat

    }

    // MARK: - Private Properties

    private static let textHeightPadding = Constants.textVerticalInset * 2
    private static let textWidthPadding = Constants.textHorizontalInset * 2

    // MARK: - Public Methods

    static func resolve(
        videoWidth: CGFloat,
        videoHeight: CGFloat,
        selectedPosition: TranscriptOverlayPosition,
        selectedSize: TranscriptOverlaySize,
        text: String,
        style: TranscriptStyle? = nil
    ) -> Layout {
        guard videoWidth > 0, videoHeight > 0 else {
            return Layout(
                overlayFrame: .zero,
                textFrame: .zero,
                controlsAnchor: .zero,
                targetWidth: 0,
                fontSize: 0
            )
        }

        let resolvedStyle = resolvedStyle(for: style)
        let availableWidth = max(videoWidth - (Constants.uniformInset * 2), 0)
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
        let textWidth = max(targetWidth - textWidthPadding, 1)
        let baseFontSize = max(videoHeight * baseFontRatio, Constants.minimumFontSize)
        let maximumOverlayHeight = max(
            videoHeight - (Constants.uniformInset * 2),
            baseFontSize
        )
        let maximumTextHeight = max(maximumOverlayHeight - textHeightPadding, baseFontSize)
        let fontSize = fittedFontSize(
            startingFrom: baseFontSize,
            for: text,
            textWidth: textWidth,
            maximumTextHeight: maximumTextHeight,
            style: resolvedStyle
        )
        let measuredTextHeight = measuredTextHeight(
            for: text,
            textWidth: textWidth,
            fontSize: fontSize,
            style: resolvedStyle
        )
        let requestedOverlayHeight = measuredTextHeight + textHeightPadding
        let overlayHeight = min(requestedOverlayHeight, maximumOverlayHeight)
        let overlayY: CGFloat

        switch selectedPosition {
        case .top:
            overlayY = Constants.uniformInset
        case .center:
            overlayY = (videoHeight - overlayHeight) / 2
        case .bottom:
            overlayY = videoHeight - overlayHeight - Constants.uniformInset
        }

        let maximumOverlayY = max(
            videoHeight - overlayHeight - Constants.uniformInset,
            Constants.uniformInset
        )
        let clampedOverlayY = min(max(overlayY, Constants.uniformInset), maximumOverlayY)

        let overlayFrame = CGRect(
            x: Constants.uniformInset,
            y: clampedOverlayY,
            width: targetWidth,
            height: overlayHeight
        )
        let textFrame = overlayFrame.insetBy(
            dx: Constants.textHorizontalInset,
            dy: Constants.textVerticalInset
        )
        let controlsY = max(overlayFrame.minY - 34, 14)
        let fallbackControlsY = min(overlayFrame.maxY + 34, videoHeight - 14)
        let preferredControlsY = overlayFrame.minY > 52 ? controlsY : fallbackControlsY

        return Layout(
            overlayFrame: overlayFrame,
            textFrame: textFrame,
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
        text: String,
        style: TranscriptStyle? = nil
    ) -> Layout {
        guard exportCanvasSize.width > 0, exportCanvasSize.height > 0 else {
            return resolve(
                videoWidth: previewCanvasSize.width,
                videoHeight: previewCanvasSize.height,
                selectedPosition: selectedPosition,
                selectedSize: selectedSize,
                text: text,
                style: style
            )
        }

        let exportLayout = resolve(
            videoWidth: exportCanvasSize.width,
            videoHeight: exportCanvasSize.height,
            selectedPosition: selectedPosition,
            selectedSize: selectedSize,
            text: text,
            style: style
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
                textFrame: .zero,
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
        let textFrame = CGRect(
            x: layout.textFrame.minX * widthScale,
            y: layout.textFrame.minY * heightScale,
            width: layout.textFrame.width * widthScale,
            height: layout.textFrame.height * heightScale
        )

        return Layout(
            overlayFrame: overlayFrame,
            textFrame: textFrame,
            controlsAnchor: CGPoint(
                x: layout.controlsAnchor.x * widthScale,
                y: layout.controlsAnchor.y * heightScale
            ),
            targetWidth: layout.targetWidth * widthScale,
            fontSize: layout.fontSize * fontScale
        )
    }

    private static func fittedFontSize(
        startingFrom baseFontSize: CGFloat,
        for text: String,
        textWidth: CGFloat,
        maximumTextHeight: CGFloat,
        style: TranscriptStyle
    ) -> CGFloat {
        var fontSize = baseFontSize
        var estimatedHeight = measuredTextHeight(
            for: text,
            textWidth: textWidth,
            fontSize: fontSize,
            style: style
        )

        guard estimatedHeight > maximumTextHeight else { return fontSize }

        let minimumFontSize = Constants.minimumFontSize

        while estimatedHeight > maximumTextHeight, fontSize > minimumFontSize {
            fontSize = max(fontSize - 1, minimumFontSize)
            estimatedHeight = measuredTextHeight(
                for: text,
                textWidth: textWidth,
                fontSize: fontSize,
                style: style
            )
        }

        return fontSize
    }

    private static func measuredTextHeight(
        for text: String,
        textWidth: CGFloat,
        fontSize: CGFloat,
        style: TranscriptStyle
    ) -> CGFloat {
        TranscriptTextStyleResolver.measuredTextHeight(
            text: text,
            style: style,
            fontSize: fontSize,
            targetWidth: textWidth
        )
    }

    private static func resolvedStyle(
        for style: TranscriptStyle?
    ) -> TranscriptStyle {
        style
            ?? TranscriptStyle(
                id: Constants.defaultStyleID,
                name: "Default",
                fontFamily: "SF Pro Rounded"
            )
    }

}
