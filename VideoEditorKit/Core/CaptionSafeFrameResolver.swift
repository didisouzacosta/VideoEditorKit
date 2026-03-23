import CoreGraphics

struct CaptionSafeFrameResolver {
    nonisolated static func resolve(
        renderSize: CGSize,
        safeArea: CaptionSafeArea
    ) -> CGRect {
        let width = max(0, renderSize.width - safeArea.leftInset - safeArea.rightInset)
        let height = max(0, renderSize.height - safeArea.topInset - safeArea.bottomInset)

        return CGRect(
            x: safeArea.leftInset,
            y: safeArea.topInset,
            width: width,
            height: height
        )
    }
}
