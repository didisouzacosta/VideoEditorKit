import SwiftUI
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("VideoEditorPlayerStageViewHitTestingTests")
struct VideoEditorPlayerStageViewHitTestingTests {

    // MARK: - Public Methods

    @Test
    func trailingControlsAreNotCoveredByTheCanvasGestureLayer() {
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

        let hitView = host.view.hitTest(
            CGPoint(x: 280, y: 320),
            with: nil
        )

        #expect(hitView?.hasCanvasInteractionGestureRecognizer == false)
    }

}

extension UIView {

    // MARK: - Private Properties

    fileprivate var hasCanvasInteractionGestureRecognizer: Bool {
        guard let gestureRecognizers else { return false }

        return gestureRecognizers.contains { recognizer in
            recognizer is UIPanGestureRecognizer
                || recognizer is UIPinchGestureRecognizer
        }
    }

}
