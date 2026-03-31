import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("VideoCanvasMappingActorTests")
struct VideoCanvasMappingActorTests {

    // MARK: - Public Methods

    @Test
    func previewLayoutFitsThePresetCanvasIntoTheAvailablePreviewSpace() async {
        let actor = VideoCanvasMappingActor()
        let request = await actor.makeRenderRequest(
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

        let layout = await actor.makePreviewLayout(
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
    func exportMappingUsesTheResolvedPresetRenderSizeAndCanvasOffset() async {
        let actor = VideoCanvasMappingActor()
        let request = await actor.makeRenderRequest(
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

        let mapping = await actor.makeExportMapping(request: request)

        #expect(mapping.renderSize == CGSize(width: 1080, height: 1350))
        #expect(mapping.orientedSourceSize == CGSize(width: 1920, height: 1080))
        #expect(mapping.aspectFillScale > 1.8)
        #expect(mapping.totalRotationRadians > 1.8)
    }

    @Test
    func previewLayoutUsesTheSameZoomedScaleAsTheExportMapping() async {
        let actor = VideoCanvasMappingActor()
        let request = await actor.makeRenderRequest(
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

        let layout = await actor.makePreviewLayout(
            request: request,
            availableSize: CGSize(width: 320, height: 400)
        )
        let mapping = await actor.makeExportMapping(request: request)

        #expect(abs(layout.contentScale - mapping.aspectFillScale) < 0.0001)
    }

}
