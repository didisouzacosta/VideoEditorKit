import CoreGraphics

struct VideoCanvasPinchPanGesturePolicy {

    // MARK: - Public Methods

    static func translation(
        from startLocation: CGPoint,
        to currentLocation: CGPoint
    ) -> CGSize {
        guard
            startLocation.x.isFinite,
            startLocation.y.isFinite,
            currentLocation.x.isFinite,
            currentLocation.y.isFinite
        else {
            return .zero
        }

        return CGSize(
            width: currentLocation.x - startLocation.x,
            height: currentLocation.y - startLocation.y
        )
    }

}
