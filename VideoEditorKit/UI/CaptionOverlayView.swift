import SwiftUI

struct CaptionOverlayView: View {
    let captions: [VideoEditorPreviewCaption]
    let renderSize: CGSize
    let displaySize: CGSize

    var body: some View {
        ZStack {
            ForEach(captions) { caption in
                Text(caption.text)
                    .font(font(for: caption.style))
                    .foregroundStyle(Color(uiColor: caption.style.textColor))
                    .multilineTextAlignment(.center)
                    .padding(caption.style.padding)
                    .background(background(for: caption.style))
                    .clipShape(.rect(cornerRadius: caption.style.cornerRadius))
                    .position(displayPoint(for: caption.center))
                    .accessibilityLabel(caption.text)
            }
        }
    }
}

private extension CaptionOverlayView {
    func background(for style: CaptionStyle) -> some ShapeStyle {
        if let backgroundColor = style.backgroundColor {
            return AnyShapeStyle(Color(uiColor: backgroundColor))
        }

        return AnyShapeStyle(.clear)
    }

    func font(for style: CaptionStyle) -> Font {
        let resolvedFont = style.resolvedFont()
        return .custom(resolvedFont.fontName, size: resolvedFont.pointSize)
    }

    func displayPoint(for renderPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: scaledAxis(renderPoint.x, renderDimension: renderSize.width, displayDimension: displaySize.width),
            y: scaledAxis(renderPoint.y, renderDimension: renderSize.height, displayDimension: displaySize.height)
        )
    }

    func scaledAxis(
        _ value: CGFloat,
        renderDimension: CGFloat,
        displayDimension: CGFloat
    ) -> CGFloat {
        guard renderDimension > 0 else {
            return 0
        }

        return (value / renderDimension) * displayDimension
    }
}
