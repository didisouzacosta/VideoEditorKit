import CoreGraphics

struct VideoEditorPreviewSnapshot: Equatable {
    let layout: LayoutResult
    let safeFrame: CGRect
    let captions: [VideoEditorPreviewCaption]
}

struct VideoEditorPreviewCaption: Identifiable, Equatable {
    let id: Caption.ID
    let text: String
    let frame: CGRect
    let style: CaptionStyle

    nonisolated var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}
