import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("VideoCanvasMappingActorTests")
struct VideoCanvasMappingActorTests {

    // MARK: - Public Methods

    @Test
    func previewLayoutFitsThePresetCanvasIntoTheAvailablePreviewSpace() {
        let actor = VideoCanvasMappingActor()
        let request = actor.makeRenderRequest(
            source: VideoCanvasSourceDescriptor(
                naturalSize: CGSize(width: 1920, height: 1080),
                preferredTransform: .identity,
                userRotationDegrees: 0,
                isMirrored: false
            ),
            snapshot: VideoCanvasSnapshot(
                preset: .social(platform: .instagram),
                transform: .identity,
                showsSafeAreaOverlay: true
            )
        )

        let layout = actor.makePreviewLayout(
            request: request,
            availableSize: CGSize(width: 320, height: 360)
        )

        #expect(abs(layout.previewCanvasSize.width - 202.5) < 0.0001)
        #expect(abs(layout.previewCanvasSize.height - 360) < 0.0001)
        #expect(abs(layout.contentBaseSize.width - 360) < 0.0001)
        #expect(abs(layout.contentBaseSize.height - 202.5) < 0.0001)
        #expect(abs(layout.contentScale - 1.7777777778) < 0.0001)
    }

    @Test
    func exportMappingUsesTheResolvedPresetRenderSizeAndCanvasOffset() {
        let actor = VideoCanvasMappingActor()
        let request = actor.makeRenderRequest(
            source: VideoCanvasSourceDescriptor(
                naturalSize: CGSize(width: 1920, height: 1080),
                preferredTransform: .identity,
                userRotationDegrees: 90,
                isMirrored: true
            ),
            snapshot: VideoCanvasSnapshot(
                preset: .facebookPost,
                transform: .init(
                    normalizedOffset: CGPoint(x: 0.15, y: -0.1),
                    zoom: 1.5,
                    rotationRadians: 0.25
                ),
                showsSafeAreaOverlay: false
            )
        )

        let mapping = actor.makeExportMapping(request: request)

        #expect(mapping.renderSize == CGSize(width: 1080, height: 1350))
        #expect(mapping.orientedSourceSize == CGSize(width: 1920, height: 1080))
        #expect(mapping.aspectFillScale > 1.8)
        #expect(mapping.totalRotationRadians > 1.8)
    }

    @Test
    func previewLayoutUsesTheSameZoomedScaleAsTheExportMapping() {
        let actor = VideoCanvasMappingActor()
        let request = actor.makeRenderRequest(
            source: VideoCanvasSourceDescriptor(
                naturalSize: CGSize(width: 1920, height: 1080),
                preferredTransform: .identity,
                userRotationDegrees: 0,
                isMirrored: false
            ),
            snapshot: VideoCanvasSnapshot(
                preset: .facebookPost,
                transform: .init(
                    normalizedOffset: CGPoint(x: 0.12, y: -0.08),
                    zoom: 1.5,
                    rotationRadians: 0.18
                ),
                showsSafeAreaOverlay: false
            )
        )

        let layout = actor.makePreviewLayout(
            request: request,
            availableSize: CGSize(width: 320, height: 400)
        )
        let mapping = actor.makeExportMapping(request: request)

        #expect(abs(layout.contentScale - mapping.aspectFillScale) < 0.0001)
    }

    @Test
    func magnifiedTransformKeepsThePinchAnchorStableInsideThePreviewCanvas() {
        let actor = VideoCanvasMappingActor()

        let transform = actor.magnifiedTransform(
            from: .identity,
            magnification: 2,
            anchor: CGPoint(x: 150, y: 50),
            previewCanvasSize: CGSize(width: 200, height: 100)
        )

        #expect(abs(transform.zoom - 2) < 0.0001)
        #expect(abs(transform.normalizedOffset.x + 0.25) < 0.0001)
        #expect(abs(transform.normalizedOffset.y) < 0.0001)
    }

    @Test
    func interactiveTransformCombinesPanPinchAndRotationFromTheSameBaseline() {
        let actor = VideoCanvasMappingActor()
        let baseline = VideoCanvasTransform(
            normalizedOffset: CGPoint(x: 0.12, y: -0.08),
            zoom: 1.3,
            rotationRadians: 0.18
        )
        let previewCanvasSize = CGSize(width: 240, height: 180)

        let combined = actor.interactiveTransform(
            from: baseline,
            translation: CGSize(width: 36, height: -18),
            magnification: 1.4,
            anchor: CGPoint(x: 180, y: 40),
            rotation: .degrees(12),
            previewCanvasSize: previewCanvasSize
        )

        var expected = actor.magnifiedTransform(
            from: baseline,
            magnification: 1.4,
            anchor: CGPoint(x: 180, y: 40),
            previewCanvasSize: previewCanvasSize
        )
        expected = actor.dragTransform(
            from: expected,
            translation: CGSize(width: 36, height: -18),
            previewCanvasSize: previewCanvasSize
        )
        expected = actor.rotatedTransform(
            from: expected,
            rotation: .degrees(12)
        )

        #expect(combined == expected)
        #expect(combined.zoom > baseline.zoom)
        #expect(combined.rotationRadians > baseline.rotationRadians)
        #expect(combined.normalizedOffset != baseline.normalizedOffset)
    }

}
