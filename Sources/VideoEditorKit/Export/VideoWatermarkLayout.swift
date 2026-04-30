import CoreGraphics

/// Resolves the export-space frame for a host-provided watermark image.
public enum VideoWatermarkLayout {

    // MARK: - Public Properties

    public static let padding: CGFloat = 16

    // MARK: - Public Methods

    public static func frame(
        renderSize: CGSize,
        imageSize: CGSize,
        position: VideoWatermarkPosition
    ) -> CGRect {
        let width = max(imageSize.width, 0)
        let height = max(imageSize.height, 0)
        let maxOriginX = max(renderSize.width - width - padding, padding)
        let maxOriginY = max(renderSize.height - height - padding, padding)

        let origin: CGPoint =
            switch position {
            case .topLeading:
                CGPoint(x: padding, y: padding)
            case .topTrailing:
                CGPoint(x: maxOriginX, y: padding)
            case .bottomLeading:
                CGPoint(x: padding, y: maxOriginY)
            case .bottomTrailing:
                CGPoint(x: maxOriginX, y: maxOriginY)
            }

        return CGRect(
            origin: origin,
            size: CGSize(width: width, height: height)
        )
    }

}
