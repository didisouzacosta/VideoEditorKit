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
        let renderWidth = resolvedDimension(renderSize.width)
        let renderHeight = resolvedDimension(renderSize.height)
        let width = resolvedDimension(imageSize.width)
        let height = resolvedDimension(imageSize.height)

        let origin: CGPoint =
            switch position {
            case .topLeading:
                CGPoint(x: padding, y: padding)
            case .topTrailing:
                CGPoint(x: renderWidth - width - padding, y: padding)
            case .bottomLeading:
                CGPoint(x: padding, y: renderHeight - height - padding)
            case .bottomTrailing:
                CGPoint(x: renderWidth - width - padding, y: renderHeight - height - padding)
            }

        return CGRect(
            origin: origin,
            size: CGSize(width: width, height: height)
        )
    }

    // MARK: - Private Methods

    private static func resolvedDimension(_ dimension: CGFloat) -> CGFloat {
        guard dimension.isFinite, dimension > 0 else { return 0 }
        return dimension
    }

}
