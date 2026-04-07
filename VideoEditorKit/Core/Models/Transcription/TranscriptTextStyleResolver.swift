//
//  TranscriptTextStyleResolver.swift
//  VideoEditorKit
//
//  Created by Codex on 07.04.2026.
//

import QuartzCore
import SwiftUI

enum TranscriptTextStyleResolver {

    // MARK: - Public Properties

    static let strokeWidth: CGFloat = 4
    static let strokeOffset: CGFloat = strokeWidth / 2
    static let strokeSampleCount = 16

    // MARK: - Private Properties

    private static let referenceStrokeFontSize: CGFloat = 20
    private static let defaultStrokeWidth: CGFloat = -4
    private static let measurementOptions: NSStringDrawingOptions = [
        .usesLineFragmentOrigin
    ]

    // MARK: - Public Methods

    static func attributedString(
        text: String,
        style: TranscriptStyle,
        fontSize: CGFloat,
        textColorOverride: RGBAColor? = nil,
        includesStroke: Bool = true,
        isWrapped: Bool = true
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = resolvedTextAlignment(
            for: style.textAlignment
        )
        paragraphStyle.lineBreakMode = isWrapped ? .byWordWrapping : .byClipping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: resolvedFont(
                style: style,
                fontSize: fontSize
            ),
            .foregroundColor: resolvedUIColor(textColorOverride ?? style.textColor),
            .paragraphStyle: paragraphStyle,
        ]

        if includesStroke, style.hasStroke, let strokeColor = style.strokeColor {
            attributes[.strokeColor] = resolvedUIColor(strokeColor)
            attributes[.strokeWidth] = defaultStrokeWidth
        }

        return NSAttributedString(
            string: text,
            attributes: attributes
        )
    }

    static func measuredTextHeight(
        text: String,
        style: TranscriptStyle,
        fontSize: CGFloat,
        targetWidth: CGFloat
    ) -> CGFloat {
        let resolvedFont = resolvedFont(
            style: style,
            fontSize: fontSize
        )
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedText.isEmpty == false else {
            return ceil(resolvedFont.lineHeight)
        }

        let attributedText = attributedString(
            text: trimmedText,
            style: style,
            fontSize: fontSize,
            includesStroke: false
        )
        let measurementRect = attributedText.boundingRect(
            with: CGSize(
                width: max(targetWidth, 1),
                height: .greatestFiniteMagnitude
            ),
            options: measurementOptions,
            context: nil
        )

        return max(
            ceil(measurementRect.height),
            ceil(resolvedFont.lineHeight)
        )
    }

    static func measuredWordWidth(
        text: String,
        style: TranscriptStyle,
        fontSize: CGFloat
    ) -> CGFloat {
        let attributedText = attributedString(
            text: text,
            style: style,
            fontSize: fontSize,
            includesStroke: false
        )
        let measurementRect = attributedText.boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: measurementOptions,
            context: nil
        )

        return ceil(measurementRect.width)
    }

    static func resolvedLineHeight(
        style: TranscriptStyle,
        fontSize: CGFloat
    ) -> CGFloat {
        ceil(
            resolvedFont(
                style: style,
                fontSize: fontSize
            ).lineHeight
        )
    }

    static func resolvedFont(
        style: TranscriptStyle,
        fontSize: CGFloat
    ) -> UIFont {
        let resolvedFont = UIFont.systemFont(
            ofSize: fontSize,
            weight: resolvedUIFontWeight(for: style.fontWeight)
        )

        guard let roundedDescriptor = resolvedFont.fontDescriptor.withDesign(.rounded) else {
            return resolvedFont
        }

        return UIFont(descriptor: roundedDescriptor, size: fontSize)
    }

    static func resolvedTextAlignment(
        for alignment: TranscriptTextAlignment
    ) -> NSTextAlignment {
        switch alignment {
        case .leading:
            .left
        case .center:
            .center
        case .trailing:
            .right
        }
    }

    static func resolvedCATextAlignment(
        for alignment: TranscriptTextAlignment
    ) -> CATextLayerAlignmentMode {
        switch alignment {
        case .leading:
            .left
        case .center:
            .center
        case .trailing:
            .right
        }
    }

    static func resolvedUIColor(
        _ color: RGBAColor
    ) -> UIColor {
        UIColor(
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }

    static func resolvedSwiftUIFont(
        for style: TranscriptStyle,
        fontSize: CGFloat
    ) -> Font {
        .system(
            size: fontSize,
            weight: resolvedSwiftUIFontWeight(for: style.fontWeight),
            design: .rounded
        )
    }

    static func resolvedStrokeOffsets() -> [CGSize] {
        resolvedStrokeOffsets(
            for: referenceStrokeFontSize
        )
    }

    static func resolvedStrokeOffsets(
        for fontSize: CGFloat
    ) -> [CGSize] {
        let scale = max(
            fontSize / referenceStrokeFontSize,
            1
        )
        let radius = strokeOffset * scale

        return (0..<strokeSampleCount).map { index in
            let angle = (CGFloat(index) / CGFloat(strokeSampleCount)) * 2 * .pi
            return CGSize(
                width: cos(angle) * radius,
                height: sin(angle) * radius
            )
        }
    }

    static func resolvedTextLayerContentsScale(
        for fontSize: CGFloat
    ) -> CGFloat {
        min(
            max(
                ceil(fontSize / referenceStrokeFontSize * 2),
                2
            ),
            8
        )
    }

    // MARK: - Private Methods

    private static func resolvedUIFontWeight(
        for fontWeight: TranscriptFontWeight
    ) -> UIFont.Weight {
        switch fontWeight {
        case .regular:
            .regular
        case .semibold:
            .semibold
        case .bold:
            .bold
        case .heavy:
            .heavy
        }
    }

    private static func resolvedSwiftUIFontWeight(
        for fontWeight: TranscriptFontWeight
    ) -> Font.Weight {
        switch fontWeight {
        case .regular:
            .regular
        case .semibold:
            .semibold
        case .bold:
            .bold
        case .heavy:
            .heavy
        }
    }

}
