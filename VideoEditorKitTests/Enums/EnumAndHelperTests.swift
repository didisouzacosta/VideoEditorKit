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
                .corrections,
            ]
        )
    }

    @Test
    func titlesAndSymbolsMatchTheCurrentCatalog() {
        let expectations: [(tool: ToolEnum, title: String, image: String)] = [
            (.cut, "Cut", "scissors"),
            (.speed, "Speed", "timer"),
            (.presets, "Presets", "aspectratio"),
            (.audio, "Audio", "waveform"),
            (.corrections, "Corrections", "circle.righthalf.filled"),
        ]

        for expectation in expectations {
            #expect(expectation.tool.title == expectation.title)
            #expect(expectation.tool.image == expectation.image)
            #expect(expectation.tool.id == expectation.tool.rawValue)
        }
    }

}

@Suite("VideoEditorConfigurationTests")
struct VideoEditorConfigurationTests {

    // MARK: - Public Methods

    @Test
    func toolAvailabilityHelpersProduceTheExpectedAccessStates() {
        let visibleTools = ToolAvailability.enabled([.speed, .corrections])
        let blockedTool = ToolAvailability.blocked(.presets)

        #expect(visibleTools.map(\.tool) == [.speed, .corrections])
        #expect(visibleTools.allSatisfy { $0.isEnabled })
        #expect(blockedTool.tool == .presets)
        #expect(blockedTool.isBlocked)
    }

    @Test
    func defaultConfigurationExposesAllVisibleToolsAsEnabled() {
        let configuration = VideoEditorView.Configuration()

        #expect(configuration.tools.map(\.tool) == ToolEnum.all)
        #expect(configuration.tools.allSatisfy { $0.access == .enabled })
        #expect(configuration.visibleTools == ToolEnum.all)
    }

    @Test
    func customConfigurationPreservesTheProvidedOrderAndAccessState() {
        let configuration = VideoEditorView.Configuration(
            tools: [
                .enabled(.corrections),
                .blocked(.speed),
                .enabled(.presets),
            ]
        )

        #expect(configuration.tools.map(\.tool) == [.corrections, .speed, .presets])
        #expect(configuration.isVisible(.corrections))
        #expect(configuration.isEnabled(.corrections))
        #expect(configuration.availability(for: .corrections)?.isBlocked == false)
        #expect(configuration.isBlocked(.speed))
        #expect(configuration.availability(for: .speed)?.isBlocked == true)
        #expect(configuration.isVisible(.audio) == false)
        #expect(configuration.isEnabled(.audio) == false)
        #expect(configuration.availability(for: .audio) == nil)
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

@Suite("ColorCorrectionHelperTests")
struct ColorCorrectionHelperTests {

    // MARK: - Public Methods

    @Test
    func createColorCorrectionFilterBuildsAColorControlsFilterWithCurrentCorrectionRules() throws {
        let correction = ColorCorrection(
            brightness: 0.15,
            contrast: 0.35,
            saturation: 0.8
        )

        let filter = try #require(Helpers.createColorCorrectionFilter(correction))

        #expect(filter.name == "CIColorControls")
        #expect((filter.value(forKey: CorrectionType.brightness.key) as? NSNumber)?.doubleValue == 0.15)
        #expect((filter.value(forKey: CorrectionType.contrast.key) as? NSNumber)?.doubleValue == 1.35)
        #expect((filter.value(forKey: CorrectionType.saturation.key) as? NSNumber)?.doubleValue == 1.8)
    }

    @Test
    func createColorCorrectionFiltersProducesASingleStagePipeline() {
        let correction = ColorCorrection(brightness: 0.1, contrast: 0.2, saturation: 0.3)

        let filters = Helpers.createColorCorrectionFilters(colorCorrection: correction)

        #expect(filters.count == 1)
        #expect(filters[0].name == "CIColorControls")
    }

    @Test
    func correctionTypesExposeExpectedCoreImageKeysAndIdentityBehavior() {
        #expect(CorrectionType.brightness.key == kCIInputBrightnessKey)
        #expect(CorrectionType.contrast.key == kCIInputContrastKey)
        #expect(CorrectionType.saturation.key == kCIInputSaturationKey)

        #expect(ColorCorrection().isIdentity)
        #expect(ColorCorrection(brightness: 0.002).isIdentity == false)
    }

    @Test
    func updatingChangesOnlyTheRequestedCorrectionChannel() {
        let correction = ColorCorrection(
            brightness: 0.15,
            contrast: 0.35,
            saturation: 0.8
        )

        let updatedCorrection = correction.updating(\.contrast, to: -0.25)

        #expect(abs(updatedCorrection.brightness - 0.15) < 0.0001)
        #expect(abs(updatedCorrection.contrast + 0.25) < 0.0001)
        #expect(abs(updatedCorrection.saturation - 0.8) < 0.0001)
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
    func resolvedOutputRenderSizeScalesPortraitCropUpToPortraitQualityBounds() {
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

        #expect(renderSize == CGSize(width: 720, height: 1280))
    }

}
