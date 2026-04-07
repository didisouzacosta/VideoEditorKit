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
    let activeWordID: EditableTranscriptWord.ID?
    let style: TranscriptStyle?
    let overlayPosition: TranscriptOverlayPosition
    let overlaySize: TranscriptOverlaySize
    let previewCanvasSize: CGSize
    let exportCanvasSize: CGSize

    // MARK: - Body

    var body: some View {
        let renderPlan = TranscriptOverlayLayoutResolver.resolvePreviewRenderPlan(
            exportCanvasSize: exportCanvasSize,
            previewCanvasSize: previewCanvasSize,
            selectedPosition: overlayPosition,
            selectedSize: overlaySize,
            segment: segment,
            style: resolvedStyle
        )
        let activeWordRenderPlans = TranscriptOverlayLayoutResolver.resolvePreviewActiveWordRenderPlans(
            exportCanvasSize: exportCanvasSize,
            previewCanvasSize: previewCanvasSize,
            selectedPosition: overlayPosition,
            selectedSize: overlaySize,
            segment: segment,
            style: resolvedStyle
        )

        ZStack(alignment: .topLeading) {
            if renderPlan.usesWordBlocks {
                activeWordOverlay(renderPlans: activeWordRenderPlans)
            } else {
                textOverlay(
                    segment.editedText,
                    layout: renderPlan.layout
                )
            }
        }
        .frame(
            width: previewCanvasSize.width,
            height: previewCanvasSize.height,
            alignment: .topLeading
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    // MARK: - Private Properties

    private var resolvedStyle: TranscriptStyle {
        style ?? .defaultPreviewStyle
    }

    private var textFrameAlignment: Alignment {
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

    private func textOverlay(
        _ text: String,
        layout: TranscriptOverlayLayoutResolver.Layout
    ) -> some View {
        let relativeTextFrame = CGRect(
            x: layout.textFrame.minX - layout.overlayFrame.minX,
            y: layout.textFrame.minY - layout.overlayFrame.minY,
            width: layout.textFrame.width,
            height: layout.textFrame.height
        )

        return ZStack(alignment: .topLeading) {
            ZStack(alignment: textFrameAlignment) {
                if resolvedStyle.hasStroke, let strokeColor = resolvedStyle.strokeColor {
                    strokedText(
                        text,
                        color: Color(rgba: strokeColor),
                        fontSize: layout.fontSize,
                        targetWidth: relativeTextFrame.width
                    )
                }

                overlayText(
                    text,
                    fontSize: layout.fontSize,
                    targetWidth: relativeTextFrame.width
                )
            }
            .frame(
                width: relativeTextFrame.width,
                height: relativeTextFrame.height,
                alignment: textFrameAlignment
            )
            .offset(
                x: relativeTextFrame.minX,
                y: relativeTextFrame.minY
            )
        }
        .frame(
            width: layout.overlayFrame.width,
            height: layout.overlayFrame.height,
            alignment: .topLeading
        )
        .offset(
            x: layout.overlayFrame.minX,
            y: layout.overlayFrame.minY
        )
    }

    @ViewBuilder
    private func activeWordOverlay(
        renderPlans: [TranscriptOverlayLayoutResolver.ActiveWordRenderPlan]
    ) -> some View {
        if let activeWord = activeWord(in: renderPlans) {
            let scaleKeyframes = TranscriptWordHighlightStyle.resolvedPreviewScaleKeyframes()
            let opacityKeyframes = TranscriptWordHighlightStyle.resolvedPreviewOpacityKeyframes()

            textOverlay(
                activeWord.text,
                layout: activeWord.layout
            )
            .keyframeAnimator(
                initialValue: HighlightAnimationState(),
                trigger: activeWord.wordID
            ) { content, state in
                content
                    .scaleEffect(state.scale)
                    .opacity(state.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(scaleKeyframes[0].value, duration: scaleKeyframes[0].duration)
                    CubicKeyframe(scaleKeyframes[1].value, duration: scaleKeyframes[1].duration)
                    CubicKeyframe(scaleKeyframes[2].value, duration: scaleKeyframes[2].duration)
                    CubicKeyframe(scaleKeyframes[3].value, duration: scaleKeyframes[3].duration)
                    CubicKeyframe(scaleKeyframes[4].value, duration: scaleKeyframes[4].duration)
                }

                KeyframeTrack(\.opacity) {
                    LinearKeyframe(opacityKeyframes[0].value, duration: opacityKeyframes[0].duration)
                    LinearKeyframe(opacityKeyframes[1].value, duration: opacityKeyframes[1].duration)
                    LinearKeyframe(opacityKeyframes[2].value, duration: opacityKeyframes[2].duration)
                }
            }
            .transition(.identity)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }

    private struct HighlightAnimationState {

        // MARK: - Public Properties

        var opacity = TranscriptWordHighlightStyle.previewInitialOpacity
        var scale = TranscriptWordHighlightStyle.previewInitialScale

    }

    private func activeWord(
        in renderPlans: [TranscriptOverlayLayoutResolver.ActiveWordRenderPlan]
    ) -> TranscriptOverlayLayoutResolver.ActiveWordRenderPlan? {
        guard let activeWordID else { return nil }
        return renderPlans.first { $0.wordID == activeWordID }
    }

    private func overlayText(
        _ text: String,
        fontSize: CGFloat,
        targetWidth: CGFloat
    ) -> some View {
        Text(text)
            .font(
                TranscriptTextStyleResolver.resolvedSwiftUIFont(
                    for: resolvedStyle,
                    fontSize: fontSize
                )
            )
            .foregroundStyle(Color(rgba: resolvedStyle.textColor))
            .multilineTextAlignment(multilineAlignment)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                width: targetWidth,
                alignment: textFrameAlignment
            )
    }

    private func strokedText(
        _ text: String,
        color: Color,
        fontSize: CGFloat,
        targetWidth: CGFloat
    ) -> some View {
        ZStack {
            ForEach(
                Array(TranscriptTextStyleResolver.resolvedStrokeOffsets().enumerated()),
                id: \.offset
            ) { _, offset in
                overlayText(
                    text,
                    fontSize: fontSize,
                    targetWidth: targetWidth
                )
                .foregroundStyle(color)
                .offset(x: offset.width, y: offset.height)
            }
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

    fileprivate static let defaultPreviewStyle = Self.defaultCaptionStyle

}
