import CoreGraphics

struct LayoutResult: Equatable {
    let videoFrame: CGRect
    let renderSize: CGSize
    let transform: CGAffineTransform
}
