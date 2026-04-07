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
            text: segment.editedText
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

    // MARK: - Private Methods

    private func overlayCard(
        layout: TranscriptOverlayLayoutResolver.Layout
    ) -> some View {
        ZStack(alignment: frameAlignment) {
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
            alignment: frameAlignment
        )
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
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: frameAlignment
            )
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
