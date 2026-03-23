import CoreGraphics

struct VideoEditorPreviewSnapshot: Equatable {
    let layout: LayoutResult
    let safeFrame: CGRect
    let captions: [VideoEditorPreviewCaption]
}

struct VideoEditorPreviewCaption: Identifiable, Equatable {
    let id: Caption.ID
    let text: String
    let center: CGPoint
    let style: CaptionStyle
}
