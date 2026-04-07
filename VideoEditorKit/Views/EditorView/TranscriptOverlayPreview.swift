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
    let previewCanvasSize: CGSize
    let exportCanvasSize: CGSize

    // MARK: - Body

    var body: some View {
        let previewLayout = TranscriptOverlayLayoutResolver.resolvePreviewLayout(
            exportCanvasSize: exportCanvasSize,
            previewCanvasSize: previewCanvasSize,
            selectedPosition: overlayPosition,
            selectedSize: overlaySize,
            text: segment.editedText,
            style: resolvedStyle
        )

        overlayCard(layout: previewLayout)
            .allFrame()
    }

    // MARK: - Private Properties

    private var resolvedStyle: TranscriptStyle {
        style
            ?? .defaultPreviewStyle
    }

    private var frameAlignment: Alignment {
        switch resolvedStyle.textAlignment {
        case .leading:
            .topLeading
        case .center:
            .top
        case .trailing:
            .topTrailing
        }
    }

    private var overlayAlignment: Alignment {
        switch overlayPosition {
        case .top:
            .top
        case .center:
            .center
        case .bottom:
            .bottom
        }
    }

    // MARK: - Private Methods

    private func overlayCard(
        layout: TranscriptOverlayLayoutResolver.Layout
    ) -> some View {
        ZStack(alignment: frameAlignment) {
            if resolvedStyle.hasStroke, let strokeColor = resolvedStyle.strokeColor {
                strokedText(
                    color: Color(rgba: strokeColor),
                    fontSize: layout.fontSize,
                    targetWidth: layout.textFrame.width
                )
            }

            overlayText(
                fontSize: layout.fontSize,
                targetWidth: layout.textFrame.width
            )
        }
        .frame(width: layout.textFrame.width, alignment: frameAlignment)
        .fixedSize(horizontal: false, vertical: true)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: overlayAlignment
        )
        .padding(.top, topPadding(for: layout))
        .padding(.bottom, bottomPadding(for: layout))
    }

    private func overlayText(
        fontSize: CGFloat,
        targetWidth: CGFloat
    ) -> some View {
        Text(segment.editedText)
            .font(.custom(resolvedStyle.fontFamily, size: fontSize))
            .italic(resolvedStyle.isItalic)
            .foregroundStyle(Color(rgba: resolvedStyle.textColor))
            .multilineTextAlignment(multilineAlignment)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                width: targetWidth,
                alignment: frameAlignment
            )
    }

    private func strokedText(
        color: Color,
        fontSize: CGFloat,
        targetWidth: CGFloat
    ) -> some View {
        ZStack {
            overlayText(
                fontSize: fontSize,
                targetWidth: targetWidth
            )
            .foregroundStyle(color)
            .offset(x: -1, y: 0)

            overlayText(
                fontSize: fontSize,
                targetWidth: targetWidth
            )
            .foregroundStyle(color)
            .offset(x: 1, y: 0)

            overlayText(
                fontSize: fontSize,
                targetWidth: targetWidth
            )
            .foregroundStyle(color)
            .offset(x: 0, y: -1)

            overlayText(
                fontSize: fontSize,
                targetWidth: targetWidth
            )
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

    private func topPadding(
        for layout: TranscriptOverlayLayoutResolver.Layout
    ) -> CGFloat {
        guard overlayPosition == .top else { return 0 }
        return max(layout.textFrame.minY, 0)
    }

    private func bottomPadding(
        for layout: TranscriptOverlayLayoutResolver.Layout
    ) -> CGFloat {
        guard overlayPosition == .bottom else { return 0 }
        return max(previewCanvasSize.height - layout.textFrame.maxY, 0)
    }

}

extension Color {

    // MARK: - Initializer

    fileprivate init(rgba: RGBAColor) {
        self.init(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
    }

}

extension TranscriptStyle {

    // MARK: - Private Properties

    fileprivate static let defaultPreviewStyle = Self(
        id: UUID(uuidString: "E5A04D11-329A-4C8E-B266-1E6A60A6F9F9") ?? UUID(),
        name: "Default",
        fontFamily: "SF Pro Rounded"
    )

}
