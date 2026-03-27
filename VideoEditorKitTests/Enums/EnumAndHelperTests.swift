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
                .crop,
                .audio,
                .text,
                .filters,
                .corrections,
                .frames,
            ]
        )
    }

    @Test
    func titlesAndSymbolsMatchTheCurrentCatalog() {
        let expectations: [(tool: ToolEnum, title: String, image: String)] = [
            (.cut, "Cut", "scissors"),
            (.speed, "Speed", "timer"),
            (.crop, "Crop", "crop"),
            (.audio, "Audio", "waveform"),
            (.text, "Text", "t.square.fill"),
            (.filters, "Filters", "camera.filters"),
            (.corrections, "Corrections", "circle.righthalf.filled"),
            (.frames, "Frames", "person.crop.artframe"),
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
        let visibleTools = ToolAvailability.enabled([.speed, .text])
        let blockedTool = ToolAvailability.blocked(.filters)

        #expect(visibleTools.map(\.tool) == [.speed, .text])
        #expect(visibleTools.allSatisfy { $0.isEnabled })
        #expect(blockedTool.tool == .filters)
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
                .enabled(.filters),
                .blocked(.speed),
                .enabled(.text),
            ]
        )

        #expect(configuration.tools.map(\.tool) == [.filters, .speed, .text])
        #expect(configuration.isVisible(.filters))
        #expect(configuration.isEnabled(.filters))
        #expect(configuration.availability(for: .filters)?.isBlocked == false)
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

        #expect(estimatedSize != nil)
        #expect(abs((estimatedSize ?? 0) - (VideoQuality.medium.megaBytesPerSecond * duration)) < 0.0001)
    }

}

@Suite("FilterHelperTests")
struct FilterHelperTests {

    // MARK: - Public Methods

    @Test
    func createColorFilterBuildsAColorControlsFilterWithCurrentCorrectionRules() throws {
        let correction = ColorCorrection(
            brightness: 0.15,
            contrast: 0.35,
            saturation: 0.8
        )

        let filter = try #require(Helpers.createColorFilter(correction))

        #expect(filter.name == "CIColorControls")
        #expect((filter.value(forKey: CorrectionType.brightness.key) as? NSNumber)?.doubleValue == 0.15)
        #expect((filter.value(forKey: CorrectionType.contrast.key) as? NSNumber)?.doubleValue == 1.35)
        #expect((filter.value(forKey: CorrectionType.saturation.key) as? NSNumber)?.doubleValue == 1.8)
    }

    @Test
    func createFiltersCombinesMainFilterAndColorCorrectionInOrder() {
        let mainFilter = CIFilter.photoEffectNoir()
        let correction = ColorCorrection(brightness: 0.1, contrast: 0.2, saturation: 0.3)

        let filters = Helpers.createFilters(mainFilter, colorCorrection: correction)

        #expect(filters.count == 2)
        #expect(filters[0].name == mainFilter.name)
        #expect(filters[1].name == "CIColorControls")
    }

    @Test
    func correctionTypesExposeExpectedCoreImageKeysAndIdentityBehavior() {
        #expect(CorrectionType.brightness.key == kCIInputBrightnessKey)
        #expect(CorrectionType.contrast.key == kCIInputContrastKey)
        #expect(CorrectionType.saturation.key == kCIInputSaturationKey)

        #expect(ColorCorrection().isIdentity)
        #expect(ColorCorrection(brightness: 0.002).isIdentity == false)
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
        #expect(CropperRatio.square.width == 1)
        #expect(CropperRatio.square.height == 1)
        #expect(CropperRatio.landscape3x2.width == 3)
        #expect(CropperRatio.landscape3x2.height == 2)
        #expect(CropperRatio.landscape4x3.width == 4)
        #expect(CropperRatio.landscape4x3.height == 3)
        #expect(CropperRatio.widescreen16x9.width == 16)
        #expect(CropperRatio.widescreen16x9.height == 9)
        #expect(CropperRatio.cinematic18x6.width == 18)
        #expect(CropperRatio.cinematic18x6.height == 6)
    }

    @Test
    func numericHelpersPreserveCurrentClampingAndAngleMath() {
        #expect(abs(90.0.degTorad - (.pi / 2)) < 0.0001)
        #expect(5.5.clamped(to: 1...5) == 5)
        #expect((-2.0).clamped(to: 1...5) == 1)
        #expect(270.0.nextAngle() == 0)
        #expect((-90.0).nextAngle() == 0)
    }

    @Test
    func convertSizeUsesTheLargerFrameRatioAndCurrentOffsetRule() {
        let converted = VideoEditor.convertSize(
            CGSize(width: 20, height: 10),
            fromFrame: CGSize(width: 100, height: 50),
            toFrame: CGSize(width: 200, height: 200)
        )

        #expect(abs(converted.ratio - 4) < 0.0001)
        #expect(abs(converted.size.width - 180) < 0.0001)
        #expect(abs(converted.size.height - 60) < 0.0001)
    }

}
