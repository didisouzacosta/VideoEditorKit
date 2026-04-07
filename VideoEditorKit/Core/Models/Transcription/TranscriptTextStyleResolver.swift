//
//  TranscriptTextStyleResolver.swift
//  VideoEditorKit
//
//  Created by Codex on 07.04.2026.
//

import QuartzCore
import SwiftUI

enum TranscriptTextStyleResolver {

    // MARK: - Private Properties

    private static let measurementOptions: NSStringDrawingOptions = [
        .usesLineFragmentOrigin
    ]

    // MARK: - Public Methods

    static func attributedString(
        text: String,
        style: TranscriptStyle,
        fontSize: CGFloat
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = resolvedTextAlignment(
            for: style.textAlignment
        )
        paragraphStyle.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: resolvedFont(
                style: style,
                fontSize: fontSize
            ),
            .foregroundColor: resolvedUIColor(style.textColor),
            .paragraphStyle: paragraphStyle,
        ]

        if style.hasStroke, let strokeColor = style.strokeColor {
            attributes[.strokeColor] = resolvedUIColor(strokeColor)
            attributes[.strokeWidth] = -3
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
            fontSize: fontSize
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

    static func resolvedFont(
        style: TranscriptStyle,
        fontSize: CGFloat
    ) -> UIFont {
        let resolvedFont =
            UIFont(name: style.fontFamily, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)

        guard style.isItalic else { return resolvedFont }

        guard
            let italicDescriptor = resolvedFont.fontDescriptor.withSymbolicTraits(.traitItalic)
        else {
            return UIFont.italicSystemFont(ofSize: fontSize)
        }

        return UIFont(descriptor: italicDescriptor, size: fontSize)
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

}
