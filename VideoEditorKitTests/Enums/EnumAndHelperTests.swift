import AVFoundation
import CoreGraphics
import CoreImage
import SwiftUI
import Testing
import UIKit

@testable import VideoEditorKit

@Suite("ToolEnumTests")
struct ToolEnumTests {

    // MARK: - Public Methods

    @Test
    func allExcludesCutWhileKeepingTheVisibleToolsOrder() {
        #expect(
            ToolEnum.all == [
                .speed,
                .presets,
                .audio,
                .adjusts,
            ]
        )
    }

    @Test
    func titlesAndSymbolsMatchTheCurrentCatalog() {
        let expectations: [(tool: ToolEnum, title: String, image: String, order: Int)] = [
            (.cut, "Cut", "scissors", 4),
            (.speed, "Speed", "timer", 3),
            (.presets, "Presets", "aspectratio", 0),
            (.audio, "Audio", "waveform", 1),
            (.adjusts, "Adjusts", "circle.righthalf.filled", 2),
        ]

        for expectation in expectations {
            #expect(expectation.tool.title == expectation.title)
            #expect(expectation.tool.image == expectation.image)
            #expect(expectation.tool.id == expectation.tool.rawValue)
            #expect(expectation.tool.order == expectation.order)
        }
    }

}

@Suite("VideoEditorConfigurationTests")
struct VideoEditorConfigurationTests {

    // MARK: - Public Methods

    @Test
    func toolAvailabilityHelpersProduceTheExpectedAccessStates() {
        let visibleTools = ToolAvailability.enabled([.speed, .adjusts])
        let blockedTool = ToolAvailability.blocked(.presets)

        #expect(visibleTools.map(\.tool) == [.speed, .adjusts])
        #expect(visibleTools.allSatisfy { $0.isEnabled })
        #expect(visibleTools.map(\.order) == [3, 2])
        #expect(blockedTool.tool == .presets)
        #expect(blockedTool.isBlocked)
        #expect(blockedTool.order == 0)
    }

    @Test
    func defaultConfigurationExposesAllVisibleToolsAsEnabled() {
        let configuration = VideoEditorView.Configuration()

        #expect(configuration.tools.map(\.tool) == [.presets, .audio, .adjusts, .speed])
        #expect(configuration.tools.allSatisfy { $0.access == .enabled })
        #expect(configuration.visibleTools == [.presets, .audio, .adjusts, .speed])
    }

    @Test
    func customConfigurationSortsToolsByDisplayOrderWhileKeepingAccessState() {
        let configuration = VideoEditorView.Configuration(
            tools: [
                .enabled(.adjusts),
                .blocked(.speed),
                .enabled(.presets),
            ]
        )

        #expect(configuration.tools.map(\.tool) == [.presets, .adjusts, .speed])
        #expect(configuration.isVisible(.adjusts))
        #expect(configuration.isEnabled(.adjusts))
        #expect(configuration.availability(for: .adjusts)?.isBlocked == false)
        #expect(configuration.isBlocked(.speed))
        #expect(configuration.availability(for: .speed)?.isBlocked == true)
        #expect(configuration.isVisible(.audio) == false)
        #expect(configuration.isEnabled(.audio) == false)
        #expect(configuration.availability(for: .audio) == nil)
    }

    @Test
    func customToolOrderOverridesTheDefaultDisplaySequence() {
        let configuration = VideoEditorView.Configuration(
            tools: [
                .enabled(.speed, order: 0),
                .enabled(.presets, order: 2),
                .blocked(.audio, order: 1),
            ]
        )

        #expect(configuration.tools.map(\.tool) == [.speed, .audio, .presets])
        #expect(configuration.tools.map(\.order) == [0, 1, 2])
        #expect(configuration.isBlocked(.audio))
    }

    @Test
    func blockedToolHandlerReceivesTheTappedTool() {
        var receivedTool: ToolEnum?
        let configuration = VideoEditorView.Configuration(
            tools: [.blocked(.speed)],
            onBlockedToolTap: { receivedTool = $0 }
        )

        configuration.notifyBlockedToolTap(for: .speed)

        #expect(receivedTool == .speed)
    }

    @Test
    func allToolsEnabledStaticPresetMatchesTheDefaultConfiguration() {
        let preset = VideoEditorView.Configuration.allToolsEnabled

        #expect(preset.tools == VideoEditorView.Configuration().tools)
    }

}

@Suite("VideoQualityTests")
struct VideoQualityTests {

    // MARK: - Public Methods

    @Test
    func qualityMetadataMatchesCurrentExportConfiguration() {
        #expect(VideoQuality.low.exportPresetName == AVAssetExportPresetMediumQuality)
        #expect(VideoQuality.medium.exportPresetName == AVAssetExportPresetHighestQuality)
        #expect(VideoQuality.high.exportPresetName == AVAssetExportPresetHighestQuality)

        #expect(VideoQuality.low.size == CGSize(width: 854, height: 480))
        #expect(VideoQuality.medium.size == CGSize(width: 1280, height: 720))
        #expect(VideoQuality.high.size == CGSize(width: 1920, height: 1080))
        #expect(VideoQuality.low.portraitSize == CGSize(width: 480, height: 854))
        #expect(VideoQuality.medium.portraitSize == CGSize(width: 720, height: 1280))
        #expect(VideoQuality.high.portraitSize == CGSize(width: 1080, height: 1920))

        #expect(VideoQuality.low.frameRate == 30)
        #expect(VideoQuality.medium.frameRate == 30)
        #expect(VideoQuality.high.frameRate == 60)

        #expect(VideoQuality.low.bitrate == 2.5)
        #expect(VideoQuality.medium.bitrate == 5)
        #expect(VideoQuality.high.bitrate == 8)
    }

    @Test
    func calculateVideoSizeUsesTheMegaBytesPerSecondEstimate() {
        let duration = 12.5
        let estimatedSize = VideoQuality.medium.calculateVideoSize(duration: duration)
        let portraitEstimatedSize = VideoQuality.medium.calculateVideoSize(
            duration: duration,
            layout: .portrait
        )

        #expect(estimatedSize != nil)
        #expect(abs((estimatedSize ?? 0) - (VideoQuality.medium.megaBytesPerSecond * duration)) < 0.0001)
        #expect(portraitEstimatedSize != nil)
        #expect(
            abs(
                (portraitEstimatedSize ?? 0)
                    - (VideoQuality.medium.megaBytesPerSecond(for: .portrait) * duration)
            ) < 0.0001
        )
    }

}

@Suite("ColorAdjustsHelperTests")
struct ColorAdjustsHelperTests {

    // MARK: - Public Methods

    @Test
    func createColorAdjustsFilterBuildsAColorControlsFilterWithCurrentAdjustRules() throws {
        let adjusts = ColorAdjusts(
            brightness: 0.15,
            contrast: 0.35,
            saturation: 0.8
        )

        let filter = try #require(Helpers.createColorAdjustsFilter(adjusts))

        #expect(filter.name == "CIColorControls")
        #expect((filter.value(forKey: ColorAdjustType.brightness.key) as? NSNumber)?.doubleValue == 0.15)
        #expect((filter.value(forKey: ColorAdjustType.contrast.key) as? NSNumber)?.doubleValue == 1.35)
        #expect((filter.value(forKey: ColorAdjustType.saturation.key) as? NSNumber)?.doubleValue == 1.8)
    }

    @Test
    func createColorAdjustsFiltersProducesASingleStagePipeline() {
        let adjusts = ColorAdjusts(brightness: 0.1, contrast: 0.2, saturation: 0.3)

        let filters = Helpers.createColorAdjustsFilters(colorAdjusts: adjusts)

        #expect(filters.count == 1)
        #expect(filters[0].name == "CIColorControls")
    }

    @Test
    func colorAdjustTypesExposeExpectedCoreImageKeysAndIdentityBehavior() {
        #expect(ColorAdjustType.brightness.key == kCIInputBrightnessKey)
        #expect(ColorAdjustType.contrast.key == kCIInputContrastKey)
        #expect(ColorAdjustType.saturation.key == kCIInputSaturationKey)

        #expect(ColorAdjusts().isIdentity)
        #expect(ColorAdjusts(brightness: 0.002).isIdentity == false)
    }

    @Test
    func updatingChangesOnlyTheRequestedAdjustChannel() {
        let adjusts = ColorAdjusts(
            brightness: 0.15,
            contrast: 0.35,
            saturation: 0.8
        )

        let updatedAdjusts = adjusts.updating(\.contrast, to: -0.25)

        #expect(abs(updatedAdjusts.brightness - 0.15) < 0.0001)
        #expect(abs(updatedAdjusts.contrast + 0.25) < 0.0001)
        #expect(abs(updatedAdjusts.saturation - 0.8) < 0.0001)
    }

}

@Suite("PaletteAndThemeTests")
struct PaletteAndThemeTests {

    // MARK: - Public Methods

    @Test
    func systemColorCollectionsKeepStableIdentifiers() {
        #expect(Set(SystemColorPalette.textBackgrounds.map(\.id)).count == SystemColorPalette.textBackgrounds.count)
        #expect(Set(SystemColorPalette.textForegrounds.map(\.id)).count == SystemColorPalette.textForegrounds.count)
        #expect(Set(SystemColorPalette.frameColors.map(\.id)).count == SystemColorPalette.frameColors.count)
    }

    @Test
    func matchesUsesResolvedUIColorEquality() {
        #expect(SystemColorPalette.matches(Color(uiColor: .systemBlue), Color(uiColor: .systemBlue)))
        #expect(SystemColorPalette.matches(Color(uiColor: .systemBlue), Color(uiColor: .systemRed)) == false)
    }

    @Test
    func themeNamespaceExposesExpectedSemanticColors() {
        #expect(SystemColorPalette.matches(Theme.selection, Color(uiColor: .systemBlue)))
        #expect(SystemColorPalette.matches(Theme.destructive, Color(uiColor: .systemRed)))

        _ = AnyView(
            Rectangle()
                .fill(Theme.rootBackground)
                .overlay(Theme.editorGlow)
                .background(Theme.editorBackground)
                .foregroundStyle(Theme.accent)
        )
    }

}

@Suite("MathAndRatioTests")
struct MathAndRatioTests {

    // MARK: - Public Methods

    @Test
    func cropperRatioPresetsUseTheCurrentAspectValues() {
        #expect(VideoCropFormatPreset.original.aspectRatio == nil)
        #expect(VideoCropFormatPreset.square1x1.aspectRatio == 1)
        #expect(abs((VideoCropFormatPreset.vertical9x16.aspectRatio ?? 0) - (9.0 / 16.0)) < 0.0001)
        #expect(abs((VideoCropFormatPreset.portrait4x5.aspectRatio ?? 0) - (4.0 / 5.0)) < 0.0001)
        #expect(abs((VideoCropFormatPreset.landscape16x9.aspectRatio ?? 0) - (16.0 / 9.0)) < 0.0001)
    }

    @Test
    func numericHelpersPreserveCurrentClampingAndAngleMath() {
        #expect(abs(90.0.degTorad - (.pi / 2)) < 0.0001)
        #expect(5.5.clamped(to: 1...5) == 5)
        #expect((-2.0).clamped(to: 1...5) == 1)
        #expect(270.0.nextAngle() == 0)
        #expect((-90.0).nextAngle() == 0)
    }

}

@Suite("VideoEditorGeometryTests")
struct VideoEditorGeometryTests {

    // MARK: - Public Methods

    @Test
    func resolvedPresentationSizeAccountsForTrackTransforms() {
        let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1920, ty: 0)

        let size = VideoEditor.resolvedPresentationSize(
            naturalSize: CGSize(width: 1080, height: 1920),
            preferredTransform: transform
        )

        #expect(size == CGSize(width: 1920, height: 1080))
    }

    @Test
    func resolvedRenderSizeKeepsLandscapeFourByThreeWithinQualityBounds() {
        let renderSize = VideoEditor.resolvedRenderSize(
            for: CGSize(width: 1440, height: 1080),
            constrainedTo: VideoQuality.medium.size
        )

        #expect(renderSize == CGSize(width: 960, height: 720))
    }

    @Test
    func resolvedRenderSizeKeepsSquareVideosSquare() {
        let renderSize = VideoEditor.resolvedRenderSize(
            for: CGSize(width: 1080, height: 1080),
            constrainedTo: VideoQuality.medium.size
        )

        #expect(renderSize == CGSize(width: 720, height: 720))
    }

    @Test
    func resolvedRenderSizeKeepsPortraitAspectRatioWithinQualityBounds() {
        let renderSize = VideoEditor.resolvedRenderSize(
            for: CGSize(width: 1080, height: 1920),
            constrainedTo: VideoQuality.medium.size
        )

        #expect(renderSize == CGSize(width: 406, height: 720))
    }

    @Test
    func resolvedOutputRenderLayoutUsesSocialDestinationForPortraitExports() {
        let configuration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0,
                    y: 0,
                    width: 1,
                    height: 1
                )
            ),
            presentation: .init(
                nil,
                socialVideoDestination: .instagramReels
            )
        )

        let layout = VideoEditor.resolvedOutputRenderLayout(
            for: CGSize(width: 1080, height: 1920),
            editingConfiguration: configuration
        )

        #expect(layout == .portrait)
    }

    @Test
    func resolvedBaseRenderSizeUsesPortraitCanvasForFullFrameVerticalPreset() {
        let configuration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0,
                    y: 0,
                    width: 1,
                    height: 1
                )
            ),
            presentation: .init(
                nil,
                socialVideoDestination: .tikTok
            )
        )

        let renderSize = VideoEditor.resolvedBaseRenderSize(
            for: CGSize(width: 1080, height: 1920),
            editingConfiguration: configuration,
            videoQuality: .medium
        )

        #expect(renderSize == CGSize(width: 720, height: 1280))
    }

    @Test
    func resolvedBaseRenderSizeKeepsSourceAspectForLandscapeClipsBeforePortraitCrop() {
        let configuration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0.341796875,
                    y: 0,
                    width: 0.31640625,
                    height: 1
                )
            ),
            presentation: .init(
                nil,
                socialVideoDestination: .youtubeShorts
            )
        )

        let renderSize = VideoEditor.resolvedBaseRenderSize(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: configuration,
            videoQuality: .medium
        )

        #expect(renderSize == CGSize(width: 1280, height: 720))
    }

    @Test
    func resolvedOutputRenderSizeUsesExactCanvasSizeForPortraitCropPresets() {
        let configuration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: .init(
                    x: 0.341796875,
                    y: 0,
                    width: 0.31640625,
                    height: 1
                )
            ),
            presentation: .init(
                nil,
                socialVideoDestination: .youtubeShorts
            )
        )

        let renderSize = VideoEditor.resolvedOutputRenderSize(
            for: CGSize(width: 1920, height: 1080),
            editingConfiguration: configuration,
            videoQuality: .medium
        )

        #expect(renderSize == CGSize(width: 1080, height: 1920))
    }

}
