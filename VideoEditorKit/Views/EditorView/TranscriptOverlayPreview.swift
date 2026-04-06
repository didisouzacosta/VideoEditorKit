//
//  TranscriptOverlayPreview.swift
//  VideoEditorKit
//
//  Created by Codex on 05.04.2026.
//

import SwiftUI

@MainActor
struct TranscriptOverlayPreview: View {

    // MARK: - Public Properties

    let segment: EditableTranscriptSegment
    let style: TranscriptStyle?
    let overlayPosition: TranscriptOverlayPosition
    let overlaySize: TranscriptOverlaySize
    let containerSize: CGSize

    // MARK: - Body

    var body: some View {
        let layout = TranscriptOverlayLayoutResolver.resolve(
            videoWidth: containerSize.width,
            videoHeight: containerSize.height,
            selectedPosition: overlayPosition,
            selectedSize: overlaySize,
            text: segment.editedText
        )

        overlayCard(layout: layout)
            .allFrame()
    }

    // MARK: - Private Properties

    private var resolvedStyle: TranscriptStyle {
        style
            ?? TranscriptStyle(
                id: UUID(),
                name: "Default",
                fontFamily: "SF Pro Rounded"
            )
    }

    private var textAlignment: Alignment {
        switch resolvedStyle.textAlignment {
        case .leading:
            .leading
        case .center:
            .center
        case .trailing:
            .trailing
        }
    }

    // MARK: - Private Methods

    private func overlayCard(
        layout: TranscriptOverlayLayoutResolver.Layout
    ) -> some View {
        ZStack {
            if resolvedStyle.hasStroke, let strokeColor = resolvedStyle.strokeColor {
                strokedText(
                    color: Color(rgba: strokeColor),
                    fontSize: layout.fontSize
                )
            }

            overlayText(fontSize: layout.fontSize)
        }
        .frame(
            width: layout.overlayFrame.width,
            height: layout.overlayFrame.height,
            alignment: textAlignment
        )
        .padding(.horizontal, 12)
        .position(
            x: layout.overlayFrame.midX,
            y: layout.overlayFrame.midY
        )
    }

    private func overlayText(fontSize: CGFloat) -> some View {
        Text(segment.editedText)
            .font(.custom(resolvedStyle.fontFamily, size: fontSize))
            .foregroundStyle(Color(rgba: resolvedStyle.textColor))
            .italic(resolvedStyle.isItalic)
            .multilineTextAlignment(multilineAlignment)
            .lineLimit(3)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: textAlignment)
    }

    private func strokedText(
        color: Color,
        fontSize: CGFloat
    ) -> some View {
        ZStack {
            overlayText(fontSize: fontSize)
                .foregroundStyle(color)
                .offset(x: -1, y: 0)
            overlayText(fontSize: fontSize)
                .foregroundStyle(color)
                .offset(x: 1, y: 0)
            overlayText(fontSize: fontSize)
                .foregroundStyle(color)
                .offset(x: 0, y: -1)
            overlayText(fontSize: fontSize)
                .foregroundStyle(color)
                .offset(x: 0, y: 1)
        }
    }

    private var multilineAlignment: TextAlignment {
        switch resolvedStyle.textAlignment {
        case .leading:
            .leading
        case .center:
            .center
        case .trailing:
            .trailing
        }
    }

}

extension Color {

    fileprivate init(rgba: RGBAColor) {
        self.init(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
    }

}
