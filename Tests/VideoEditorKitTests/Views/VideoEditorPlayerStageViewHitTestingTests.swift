import SwiftUI
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("VideoEditorPlayerStageViewHitTestingTests")
struct VideoEditorPlayerStageViewHitTestingTests {

    // MARK: - Public Methods

    @Test
    func trailingControlsStayBottomTrailingAndAboveTheCanvasGestureLayer() {
        let canvasState = VideoCanvasEditorState()
        canvasState.restore(
            .init(
                preset: .original,
                transform: .init(zoom: 1.25)
            )
        )

        let stage = VideoEditorPlayerStageView(
            .loaded,
            canvasEditorState: canvasState,
            source: .init(
                naturalSize: CGSize(width: 1080, height: 1080),
                preferredTransform: .identity,
                userRotationDegrees: 0,
                isMirrored: false
            ),
            isCanvasInteractive: true
        ) {
            Color.blue
        } overlay: { _ in
            EmptyView()
        } trailingControls: {
            Button("Reset") {}
                .frame(width: 64, height: 64)
        }

        let host = UIHostingController(rootView: stage)
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let bottomTrailingHitView = host.view.hitTest(
            CGPoint(x: 280, y: 320),
            with: nil
        )

        #expect(bottomTrailingHitView != nil)
        #expect(bottomTrailingHitView?.hasCanvasInteractionGestureRecognizerInHierarchy == false)
    }

    @Test
    func trailingControlsRenderInCanvasBottomTrailingCorner() throws {
        let canvasState = VideoCanvasEditorState()
        canvasState.restore(
            .init(
                preset: .original,
                transform: .init(zoom: 1.25)
            )
        )

        let stage = VideoEditorPlayerStageView(
            .loaded,
            canvasEditorState: canvasState,
            source: .init(
                naturalSize: CGSize(width: 1080, height: 1080),
                preferredTransform: .identity,
                userRotationDegrees: 0,
                isMirrored: false
            ),
            isCanvasInteractive: false
        ) {
            Color.blue
        } overlay: { _ in
            EmptyView()
        } trailingControls: {
            Color.red
                .frame(width: 64, height: 64)
        }
        .frame(width: 320, height: 400)

        let renderer = ImageRenderer(content: stage)
        renderer.scale = 1

        let cgImage = try #require(renderer.uiImage?.cgImage)

        #expect(pixelColor(in: cgImage, x: 280, y: 320)?.isRed == true)
        #expect(pixelColor(in: cgImage, x: 160, y: 200)?.isRed == false)
    }

}

private struct PixelColor {

    // MARK: - Public Properties

    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    var isRed: Bool {
        red > 200 && green < 80 && blue < 80 && alpha > 200
    }

}

private func pixelColor(
    in image: CGImage,
    x: Int,
    y: Int
) -> PixelColor? {
    guard x >= 0, y >= 0, x < image.width, y < image.height else { return nil }
    guard let dataProviderData = image.dataProvider?.data else { return nil }
    guard let data = CFDataGetBytePtr(dataProviderData) else { return nil }

    let bytesPerPixel = max(image.bitsPerPixel / 8, 1)
    let offset = (y * image.bytesPerRow) + (x * bytesPerPixel)
    guard offset + 3 < CFDataGetLength(dataProviderData) else { return nil }

    return PixelColor(
        red: data[offset],
        green: data[offset + 1],
        blue: data[offset + 2],
        alpha: data[offset + 3]
    )
}

extension UIView {

    // MARK: - Private Properties

    fileprivate var hasCanvasInteractionGestureRecognizerInHierarchy: Bool {
        if hasCanvasInteractionGestureRecognizer {
            return true
        }

        return superview?.hasCanvasInteractionGestureRecognizerInHierarchy == true
    }

    private var hasCanvasInteractionGestureRecognizer: Bool {
        guard let gestureRecognizers else { return false }

        return gestureRecognizers.contains { recognizer in
            recognizer is UIPanGestureRecognizer
                || recognizer is UIPinchGestureRecognizer
        }
    }

}
