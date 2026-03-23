import SwiftUI
import UIKit

struct CaptionOverlayView: View {
    let captions: [VideoEditorPreviewCaption]
    let renderSize: CGSize
    let displaySize: CGSize
    let selectedCaptionID: Caption.ID?
    let onSelect: (Caption.ID) -> Void
    let onMove: (Caption.ID, CGPoint) -> Void

    var body: some View {
        ZStack {
            ForEach(captions) { caption in
                Button {
                    onSelect(caption.id)
                } label: {
                    Text(caption.text)
                        .font(font(for: caption.style))
                        .foregroundStyle(Color(uiColor: caption.style.textColor))
                        .multilineTextAlignment(.center)
                        .padding(caption.style.padding)
                        .background(background(for: caption.style))
                        .clipShape(.rect(cornerRadius: caption.style.cornerRadius))
                        .overlay {
                            if selectedCaptionID == caption.id {
                                RoundedRectangle(cornerRadius: caption.style.cornerRadius, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpaceName))
                        .onChanged { value in
                            onMove(caption.id, value.location)
                        }
                )
                .position(displayPoint(for: caption.center))
                .accessibilityLabel(caption.text)
                .accessibilityAddTraits(selectedCaptionID == caption.id ? .isSelected : [])
            }
        }
        .coordinateSpace(name: coordinateSpaceName)
    }
}

private extension CaptionOverlayView {
    var coordinateSpaceName: String {
        "caption-overlay"
    }

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

#Preview {
    ZStack {
        Color.black
        CaptionOverlayView(
            captions: CaptionOverlayPreviewData.captions,
            renderSize: CGSize(width: 1080, height: 1920),
            displaySize: CGSize(width: 270, height: 480),
            selectedCaptionID: CaptionOverlayPreviewData.captions[1].id,
            onSelect: { _ in },
            onMove: { _, _ in }
        )
    }
    .frame(width: 270, height: 480)
}

private enum CaptionOverlayPreviewData {
    static var captions: [VideoEditorPreviewCaption] {
        let style = CaptionStyle(
            fontName: UIFont.boldSystemFont(ofSize: 24).fontName,
            fontSize: 24,
            textColor: .white,
            backgroundColor: UIColor.black.withAlphaComponent(0.72),
            padding: 12,
            cornerRadius: 14
        )

        return [
            VideoEditorPreviewCaption(
                id: UUID(),
                text: "Legenda centralizada",
                center: CGPoint(x: 540, y: 1540),
                style: style
            ),
            VideoEditorPreviewCaption(
                id: UUID(),
                text: "Legenda livre",
                center: CGPoint(x: 540, y: 720),
                style: style
            )
        ]
    }
}
