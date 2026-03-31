import AVFoundation
import CoreGraphics
import Testing

@testable import VideoEditorKit

@Suite("VideoEditorTests")
struct VideoEditorTests {

    // MARK: - Public Methods

    @Test
    func resolvedCropRectConvertsNormalizedGeometryIntoRenderCoordinates() {
        let cropRect = VideoEditor.resolvedCropRect(
            for: .init(
                x: 0.1,
                y: 0.2,
                width: 0.5,
                height: 0.4
            ),
            in: CGSize(width: 1000, height: 500)
        )

        #expect(cropRect == CGRect(x: 100, y: 100, width: 500, height: 200))
    }

    @Test
    func resolvedCropRectClampsOutOfBoundsValuesToTheVisibleFrame() {
        let cropRect = VideoEditor.resolvedCropRect(
            for: .init(
                x: -0.2,
                y: 0.85,
                width: 1.4,
                height: 0.5
            ),
            in: CGSize(width: 1000, height: 500)
        )

        #expect(cropRect == CGRect(x: 0, y: 424, width: 1000, height: 76))
    }

    @Test
    func resolvedOutputRenderLayoutUsesPresetAspectRatioWithoutSocialDestination() {
        let configuration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0.275,
                    y: 0,
                    width: 0.45,
                    height: 1
                )
            )
        )

        let layout = VideoEditor.resolvedOutputRenderLayout(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: configuration
        )

        #expect(layout == .portrait)
    }

    @Test
    func resolvedOutputRenderSizeUsesExactCanvasSizeForFacebookPostPresetExports() {
        let configuration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0.275,
                    y: 0,
                    width: 0.45,
                    height: 1
                )
            )
        )

        let renderSize = VideoEditor.resolvedOutputRenderSize(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: configuration,
            videoQuality: .medium
        )

        #expect(renderSize == CGSize(width: 1080, height: 1350))
    }

    @Test
    func resolvedCropRectSharesTheSameVisibleGeometryAsThePreviewLayout() throws {
        let sourceSize = CGSize(width: 1000, height: 500)
        let freeformRect = VideoEditingConfiguration.FreeformRect(
            x: 0.8,
            y: 0.1,
            width: 0.4,
            height: 0.8
        )
        let previewLayout = try #require(
            VideoCropPreviewLayout(
                freeformRect: freeformRect,
                in: sourceSize
            )
        )

        let cropRect = VideoEditor.resolvedCropRect(
            for: freeformRect,
            in: sourceSize
        )

        #expect(cropRect == previewLayout.sourceRect)
    }

    @Test
    func resolvedOutputRenderLayoutUsesTheClampedPreviewGeometryWhenCropOverflowsTheSource() {
        let configuration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0.8,
                    y: 0.1,
                    width: 0.4,
                    height: 0.8
                )
            )
        )

        let layout = VideoEditor.resolvedOutputRenderLayout(
            for: CGSize(width: 1000, height: 500),
            editingConfiguration: configuration
        )

        #expect(layout == .portrait)
    }

    @Test
    func resolvedOutputRenderSizeUsesCanvasPresetDimensionsWhenPersisted() {
        let configuration = VideoEditingConfiguration(
            canvas: .init(
                snapshot: .init(
                    preset: .facebookPost,
                    freeCanvasSize: CGSize(width: 1080, height: 1350)
                )
            )
        )

        let renderSize = VideoEditor.resolvedOutputRenderSize(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: configuration,
            videoQuality: .low
        )

        #expect(renderSize == CGSize(width: 1080, height: 1350))
    }

    @Test
    func resolvedOutputRenderLayoutUsesCanvasPresetOrientationWhenPersisted() {
        let configuration = VideoEditingConfiguration(
            canvas: .init(
                snapshot: .init(
                    preset: .custom(width: 1080, height: 1080),
                    freeCanvasSize: CGSize(width: 1080, height: 1080)
                )
            )
        )

        let layout = VideoEditor.resolvedOutputRenderLayout(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: configuration
        )

        #expect(layout == .landscape)
    }

    @Test
    func resolvedExportPresetNameUsesARealRenderPresetForVideoCompositionOnSimulator() {
        let presetName = VideoEditor.resolvedExportPresetName(
            appliesVideoComposition: true,
            isSimulatorEnvironment: true
        )

        #expect(presetName == AVAssetExportPresetHighestQuality)
    }

    @Test
    func resolvedExportPresetNameKeepsPassthroughAvailableOnlyWithoutRenderingStages() {
        let presetName = VideoEditor.resolvedExportPresetName(
            appliesVideoComposition: false,
            isSimulatorEnvironment: true
        )

        #expect(presetName == AVAssetExportPresetPassthrough)
    }

}
