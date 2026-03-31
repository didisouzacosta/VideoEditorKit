import Foundation
import SwiftUI
import Testing

@testable import VideoEditorKit

@MainActor
@Suite("EditorViewModelTests")
struct EditorViewModelTests {

    // MARK: - Public Methods

    @Test
    func selectedTrackVolumeUsesRecordedTrackWhenSelected() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.audio = Audio(
            url: URL(fileURLWithPath: "/tmp/recorded-audio.m4a"),
            duration: 12,
            volume: 0.35
        )
        viewModel.currentVideo = video

        viewModel.selectAudioTrack(.recorded)

        #expect(abs(Double(viewModel.selectedTrackVolume()) - 0.35) < 0.0001)
    }

    @Test
    func updateSelectedTrackVolumeUpdatesRecordedTrackVolume() {
        let viewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock
        video.audio = Audio(
            url: URL(fileURLWithPath: "/tmp/recorded-audio.m4a"),
            duration: 12,
            volume: 0.35
        )
        viewModel.currentVideo = video
        viewModel.selectAudioTrack(.recorded)

        viewModel.updateSelectedTrackVolume(0.8, videoPlayer: videoPlayer)

        #expect(abs(Double(viewModel.currentVideo?.audio?.volume ?? 0) - 0.8) < 0.0001)
        #expect(abs(Double(viewModel.currentVideo?.volume ?? 0) - 1.0) < 0.0001)
    }

    @Test
    func resetSpeedPreservesTimelineIndicatorPosition() {
        let viewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock
        video.rangeDuration = 20...80
        viewModel.currentVideo = video
        videoPlayer.syncPlaybackState(with: video)
        videoPlayer.currentTime = 50

        viewModel.handleRateChange(2, videoPlayer: videoPlayer)

        viewModel.reset(.speed, videoPlayer: videoPlayer)

        #expect(abs(Double(viewModel.currentVideo?.rate ?? 0) - 1.0) < 0.0001)
        #expect(abs(videoPlayer.currentTime - 50) < 0.0001)
    }

    @Test
    func exportVideoOnlyExistsWhileTheQualitySheetIsPresented() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock

        #expect(viewModel.exportVideo == nil)

        viewModel.showVideoQualitySheet = true

        #expect(viewModel.exportVideo?.id == viewModel.currentVideo?.id)
    }

    @Test
    func setCorrectionsAppliesAndRemovesTheCorrectionsTool() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        viewModel.selectTool(.corrections)

        viewModel.setCorrections(
            ColorCorrection(brightness: 0.2, contrast: 0.15, saturation: 0.1)
        )

        #expect(abs((viewModel.currentVideo?.colorCorrection.brightness ?? 0) - 0.2) < 0.0001)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .corrections) == true)

        viewModel.setCorrections(.init())

        #expect(viewModel.currentVideo?.colorCorrection == .init())
        #expect(viewModel.currentVideo?.isAppliedTool(for: .corrections) == false)
    }

    @Test
    func colorCorrectionBindingMutatesTheCurrentVideoImmediately() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        let binding = viewModel.colorCorrectionBinding()
        let correction = ColorCorrection(
            brightness: 0.2,
            contrast: -0.1,
            saturation: 0.35
        )

        binding.wrappedValue = correction

        #expect(viewModel.currentVideo?.colorCorrection == correction)
    }

    @Test
    func setCutTracksWhetherTheVideoIsCurrentlyTrimmed() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.rangeDuration = 10...80
        viewModel.currentVideo = video

        viewModel.setCut()

        #expect(viewModel.currentVideo?.isAppliedTool(for: .cut) == true)

        viewModel.currentVideo?.rangeDuration = 0...250
        viewModel.setCut()

        #expect(viewModel.currentVideo?.isAppliedTool(for: .cut) == false)
    }

    @Test
    func resetCutRestoresTheFullRangeAndClearsTheCutTool() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.rangeDuration = 15...40
        video.appliedTool(for: .cut)
        viewModel.currentVideo = video

        viewModel.resetCut()

        #expect(viewModel.currentVideo?.rangeDuration == 0...250)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .cut) == false)
    }

    @Test
    func cropRotationAndMirrorProxyTheCurrentVideoState() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock

        viewModel.cropRotation = 180
        viewModel.toggleMirror()

        #expect(viewModel.cropRotation == 180)
        #expect(viewModel.isMirrorEnabled)
    }

    @Test
    func resolvedPlayerDisplaySizeUsesTheRotatedPresentationDimensions() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        video.rotation = 90

        let displaySize = viewModel.resolvedPlayerDisplaySize(
            for: video,
            in: CGSize(width: 320, height: 220)
        )

        #expect(abs(displaySize.width - 123.75) < 0.0001)
        #expect(abs(displaySize.height - 220) < 0.0001)
    }

    @Test
    func resolvedCropPreviewCanvasKeepsReferenceAndRenderedContentSeparatedWhenNoPresetIsActive() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video

        let previewCanvas = viewModel.resolvedCropPreviewCanvas(
            for: video,
            in: CGSize(width: 320, height: 360)
        )

        #expect(abs(previewCanvas.referenceSize.width - 1920) < 0.0001)
        #expect(abs(previewCanvas.referenceSize.height - 1080) < 0.0001)
        #expect(abs(previewCanvas.contentSize.width - 320) < 0.0001)
        #expect(abs(previewCanvas.contentSize.height - 180) < 0.0001)
        #expect(previewCanvas.viewportSize == previewCanvas.contentSize)
    }

    @Test
    func resolvedCropPreviewCanvasExpandsThePresetViewportWithoutLosingTheVideoReferenceSpace() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectCropFormat(.vertical9x16)

        let previewCanvas = viewModel.resolvedCropPreviewCanvas(
            for: video,
            in: CGSize(width: 320, height: 360)
        )

        #expect(abs(previewCanvas.referenceSize.width - 1920) < 0.0001)
        #expect(abs(previewCanvas.referenceSize.height - 1080) < 0.0001)
        #expect(abs(previewCanvas.contentSize.width - 320) < 0.0001)
        #expect(abs(previewCanvas.contentSize.height - 180) < 0.0001)
        #expect(abs(previewCanvas.viewportSize.width - 202.5) < 0.0001)
        #expect(abs(previewCanvas.viewportSize.height - 360) < 0.0001)
        #expect(previewCanvas.viewportSize.height > previewCanvas.contentSize.height)
    }

    @Test
    func originalPresetIsSelectedByDefault() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video

        #expect(viewModel.selectedCropPreset() == .original)
        #expect(viewModel.isCropFormatSelected(.original))
        #expect(viewModel.shouldUseCropPresetSpotlight == false)
    }

    @Test
    func selectingVerticalCropFormatCreatesACenteredNineBySixteenRect() throws {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)

        viewModel.selectCropFormat(.vertical9x16)

        let cropRect = try #require(viewModel.cropFreeformRect)
        #expect(abs(cropRect.x - 0.341796875) < 0.0001)
        #expect(abs(cropRect.width - 0.31640625) < 0.0001)
        #expect(abs(cropRect.y - 0) < 0.0001)
        #expect(abs(cropRect.height - 1) < 0.0001)
        #expect(viewModel.selectedTools == nil)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .presets) == true)
        #expect(viewModel.shouldShowCropOverlay)
        #expect(viewModel.isCropOverlayInteractive)
        #expect(viewModel.shouldUseCropPresetSpotlight)
        #expect(viewModel.isCropFormatSelected(.vertical9x16))
        #expect(viewModel.socialVideoDestination == .instagramReels)
        #expect(viewModel.showsSafeAreaOverlay)
        #expect(viewModel.shouldShowSafeAreaOverlay)
    }

    @Test
    func selectingOriginalCropFormatClearsThePresetRect() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectCropFormat(.vertical9x16)

        viewModel.selectCropFormat(.original)

        #expect(viewModel.cropFreeformRect == nil)
        #expect(viewModel.shouldShowCropOverlay == false)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .presets) == false)
        #expect(viewModel.isCropFormatSelected(.original))
        #expect(viewModel.socialVideoDestination == nil)
        #expect(viewModel.showsSafeAreaOverlay == false)
        #expect(viewModel.isCropOverlayInteractive == false)
        #expect(viewModel.shouldUseCropPresetSpotlight == false)
        #expect(viewModel.selectedCropPresetBadgeTitle() == "Original")
        #expect(viewModel.selectedCropPresetBadgeDimension() == "1920x1080")
    }

    @Test
    func selectingVerticalCropFormatAlsoUpdatesTheCanvasEditorState() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)

        viewModel.selectCropFormat(.vertical9x16)

        #expect(viewModel.canvasEditorState.preset == .social(platform: .instagram))
        #expect(viewModel.canvasEditorState.transform == .identity)
        #expect(viewModel.canvasEditorState.showsSafeAreaOverlay)
    }

    @Test
    func selectingSocialVideoDestinationUpdatesIntentWithoutDependingOnGeometryInference() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1080, height: 1920)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)

        viewModel.selectSocialVideoDestination(.youtubeShorts)

        #expect(viewModel.socialVideoDestination == .youtubeShorts)
        #expect(viewModel.isCropFormatSelected(.vertical9x16))
        #expect(viewModel.isSocialVideoDestinationSelected(.youtubeShorts))
        #expect(viewModel.selectedCropPreset() == .vertical9x16)
        #expect(viewModel.selectedCropPresetBadgeTitle() == "Social")
        #expect(viewModel.selectedCropPresetBadgeDimension() == "9:16")
        #expect(viewModel.showsSafeAreaOverlay)
    }

    @Test
    func activeSafeAreaPlatformMatchesTheSelectedDestination() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1080, height: 1920)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)

        viewModel.selectSocialVideoDestination(.youtubeShorts)

        #expect(viewModel.activeSafeAreaPlatform == .youtubeShorts)
    }

    @Test
    func safeAreaOverlayOnlyAppearsWhenTheGuideToggleIsEnabled() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1080, height: 1920)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectSocialVideoDestination(.tikTok)

        viewModel.showsSafeAreaOverlay = false

        #expect(viewModel.shouldShowSafeAreaOverlay == false)
        #expect(viewModel.activeSafeAreaPlatform == nil)
    }

    @Test
    func selectingPortraitPresetClearsSocialDestinationAndUpdatesTheBadge() throws {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectSocialVideoDestination(.instagramReels)

        viewModel.selectCropFormat(.portrait4x5)

        let cropRect = try #require(viewModel.cropFreeformRect)
        #expect(abs(cropRect.x - 0.275) < 0.0001)
        #expect(abs(cropRect.width - 0.45) < 0.0001)
        #expect(viewModel.socialVideoDestination == nil)
        #expect(viewModel.showsSafeAreaOverlay == false)
        #expect(viewModel.shouldUseCropPresetSpotlight)
        #expect(viewModel.selectedCropPreset() == .portrait4x5)
        #expect(viewModel.selectedCropPresetBadgeTitle() == "4:5")
        #expect(viewModel.selectedCropPresetBadgeDimension() == "4:5")
    }

    @Test
    func currentEditingConfigurationPersistsActivePresetPresentationState() throws {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectSocialVideoDestination(.instagramReels)

        let configuration = try #require(
            viewModel.currentEditingConfiguration(currentTimelineTime: 12)
        )
        let cropRect = try #require(configuration.crop.freeformRect)
        let activeRect = try #require(viewModel.cropFreeformRect)

        #expect(configuration.presentation.socialVideoDestination == .instagramReels)
        #expect(configuration.presentation.showsSafeAreaGuides)
        #expect(configuration.playback.currentTimelineTime == 12)
        #expect(cropRect == activeRect)
        #expect(configuration.canvas.snapshot.preset == .social(platform: .instagram))
        #expect(configuration.canvas.snapshot.showsSafeAreaOverlay)
    }

    @Test
    func currentEditingConfigurationPersistsCanvasTransform() throws {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.canvasEditorState.restore(
            .init(
                preset: .facebookPost,
                freeCanvasSize: CGSize(width: 1080, height: 1350),
                transform: .init(
                    normalizedOffset: CGPoint(x: 0.18, y: -0.06),
                    zoom: 1.25,
                    rotationRadians: 0.2
                ),
                showsSafeAreaOverlay: false
            )
        )

        let configuration = try #require(viewModel.currentEditingConfiguration())

        #expect(configuration.canvas.snapshot.preset == .facebookPost)
        #expect(abs(configuration.canvas.snapshot.transform.normalizedOffset.x - 0.18) < 0.0001)
        #expect(abs(configuration.canvas.snapshot.transform.normalizedOffset.y + 0.06) < 0.0001)
        #expect(abs(configuration.canvas.snapshot.transform.zoom - 1.25) < 0.0001)
        #expect(abs(configuration.canvas.snapshot.transform.rotationRadians - 0.2) < 0.0001)
    }

    @Test
    func restorePendingEditingPresentationStateSynthesizesCanvasSnapshotFromLegacyCrop() async {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.prepareEditingConfigurationForInitialLoad(
            VideoEditingConfiguration(
                crop: .init(
                    freeformRect: .init(
                        x: 0.341796875,
                        y: 0,
                        width: 0.31640625,
                        height: 1
                    )
                ),
                presentation: .init(
                    socialVideoDestination: .tikTok,
                    showsSafeAreaGuides: true
                )
            ),
            videoPlayer: VideoPlayerManager()
        )

        await viewModel.restorePendingEditingPresentationState()

        #expect(viewModel.canvasEditorState.preset == .social(platform: .tiktok))
        #expect(viewModel.canvasEditorState.showsSafeAreaOverlay)
        #expect(viewModel.canvasEditorState.transform == .identity)
    }

    @Test
    func restorePendingEditingPresentationStateRestoresPersistedCanvasSnapshotVerbatim() async {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video

        let persistedSnapshot = VideoCanvasSnapshot(
            preset: .facebookPost,
            freeCanvasSize: CGSize(width: 1080, height: 1350),
            transform: .init(
                normalizedOffset: CGPoint(x: 0.14, y: -0.09),
                zoom: 1.6,
                rotationRadians: 0.22
            ),
            showsSafeAreaOverlay: false
        )

        viewModel.prepareEditingConfigurationForInitialLoad(
            VideoEditingConfiguration(
                canvas: .init(snapshot: persistedSnapshot),
                presentation: .init(
                    socialVideoDestination: .instagramReels,
                    showsSafeAreaGuides: true
                )
            ),
            videoPlayer: VideoPlayerManager()
        )

        await viewModel.restorePendingEditingPresentationState()

        #expect(viewModel.canvasEditorState.snapshot() == persistedSnapshot)
        #expect(viewModel.socialVideoDestination == .instagramReels)
        #expect(viewModel.showsSafeAreaOverlay == true)
    }

    @Test
    func setAudioSwitchesToRecordedTrackAndMarksAudioTool() throws {
        let viewModel = EditorViewModel()
        let audioURL = try TestFixtures.createTemporaryAudio()
        defer { FileManager.default.removeIfExists(for: audioURL) }

        viewModel.currentVideo = Video.mock
        viewModel.selectTool(.audio)

        viewModel.setAudio(Audio(url: audioURL, duration: 3, volume: 0.5))

        #expect(viewModel.currentVideo?.audio?.url == audioURL)
        #expect(viewModel.selectedAudioTrack == .recorded)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == true)
    }

    @Test
    func removeAudioDeletesTheRecordedFileAndRestoresTheVideoTrackSelection() throws {
        let viewModel = EditorViewModel()
        let audioURL = try TestFixtures.createTemporaryAudio()
        var video = Video.mock
        video.audio = Audio(url: audioURL, duration: 4, volume: 0.7)
        video.appliedTool(for: .audio)
        viewModel.currentVideo = video
        viewModel.selectTool(.audio)
        viewModel.selectedAudioTrack = .recorded

        viewModel.removeAudio()

        #expect(FileManager.default.fileExists(atPath: audioURL.path()) == false)
        #expect(viewModel.currentVideo?.audio == nil)
        #expect(viewModel.selectedAudioTrack == .video)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == false)
    }

    @Test
    func selectingRecordedTrackFallsBackToVideoWhenNoRecordedAudioExists() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock

        viewModel.selectAudioTrack(.recorded)

        #expect(viewModel.selectedAudioTrack == .video)
    }

    @Test
    func updateSelectedTrackVolumeRemovesTheAudioToolWhenBackAtDefaults() {
        let viewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock
        video.appliedTool(for: .audio)
        viewModel.currentVideo = video
        viewModel.selectedAudioTrack = .video

        viewModel.updateSelectedTrackVolume(1.0, videoPlayer: videoPlayer)

        #expect(abs(Double(viewModel.currentVideo?.volume ?? 0) - 1.0) < 0.0001)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == false)
    }

    @Test
    func editingConfigurationChangeCounterAdvancesWhenEditingStateMutates() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        let initialCounter = viewModel.editingConfigurationChangeCounter

        viewModel.selectTool(.corrections)
        viewModel.setCorrections(ColorCorrection(brightness: 0.2))

        #expect(viewModel.editingConfigurationChangeCounter > initialCounter)
    }

    @Test
    func frameBindingsAdvanceTheEditingConfigurationChangeCounter() {
        let viewModel = EditorViewModel()
        let initialCounter = viewModel.editingConfigurationChangeCounter
        let colorBinding = viewModel.frameColorBinding()
        let scaleBinding = viewModel.frameScaleBinding()

        colorBinding.wrappedValue = .red
        scaleBinding.wrappedValue = 0.35

        #expect(viewModel.editingConfigurationChangeCounter >= initialCounter + 2)
    }

    @Test
    func selectToolIgnoresBlockedAndHiddenToolsFromAvailability() {
        let viewModel = EditorViewModel()
        viewModel.setToolAvailability([
            .init(.corrections),
            .init(.speed, access: .blocked),
        ])

        viewModel.selectTool(.corrections)
        #expect(viewModel.selectedTools == .corrections)

        viewModel.selectTool(.speed)
        #expect(viewModel.selectedTools == .corrections)

        viewModel.selectTool(.audio)
        #expect(viewModel.selectedTools == .corrections)
    }

    @Test
    func changingAvailabilityClearsTheCurrentSelectionWhenItBecomesUnavailable() {
        let viewModel = EditorViewModel()
        viewModel.selectTool(.corrections)

        viewModel.setToolAvailability([
            .init(.speed),
            .init(.presets),
        ])

        #expect(viewModel.selectedTools == nil)
    }

    @Test
    func frameBindingsMutateTheSharedFramesState() {
        let viewModel = EditorViewModel()
        let colorBinding = viewModel.frameColorBinding()
        let scaleBinding = viewModel.frameScaleBinding()

        colorBinding.wrappedValue = .red
        scaleBinding.wrappedValue = 0.35

        #expect(SystemColorPalette.matches(viewModel.frames.frameColor, .red))
        #expect(abs(viewModel.frames.scaleValue - 0.35) < 0.0001)
    }

    @Test
    func playerContainerSizeUsesWidthInsetAndMinimumHeight() {
        let viewModel = EditorViewModel()

        let compactSize = viewModel.playerContainerSize(in: CGSize(width: 300, height: 400))
        let tallSize = viewModel.playerContainerSize(in: CGSize(width: 300, height: 900))

        #expect(abs(compactSize.width - 268) < 0.0001)
        #expect(abs(compactSize.height - 220) < 0.0001)
        #expect(abs(tallSize.height - 360) < 0.0001)
    }

    @Test
    func presentExporterShowsTheQualitySheetAfterTheDeferredDelay() async {
        let viewModel = EditorViewModel()
        viewModel.selectTool(.corrections)

        viewModel.presentExporter()

        #expect(viewModel.selectedTools == nil)
        #expect(viewModel.showVideoQualitySheet == false)

        for _ in 0..<10 where !viewModel.showVideoQualitySheet {
            try? await Task.sleep(for: .milliseconds(100))
        }

        #expect(viewModel.showVideoQualitySheet)
    }

    @Test
    func prepareEditingConfigurationForInitialLoadSeedsPlayerAndRestoresPresentationState() async throws {
        let viewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        let audioURL = try TestFixtures.createTemporaryAudio()
        defer { FileManager.default.removeIfExists(for: audioURL) }

        let editingConfiguration = VideoEditingConfiguration(
            trim: .init(lowerBound: 8, upperBound: 24),
            playback: .init(
                rate: 1.5,
                videoVolume: 0.55,
                currentTimelineTime: 11
            ),
            crop: .init(
                rotationDegrees: 90,
                isMirrored: true,
                freeformRect: .init(
                    x: 0.15,
                    y: 0.1,
                    width: 0.7,
                    height: 0.65
                )
            ),
            corrections: .init(
                brightness: 0.1,
                contrast: 1.2,
                saturation: 0.7
            ),
            frame: .init(
                scaleValue: 0.2,
                colorToken: "palette:blue"
            ),
            audio: .init(
                recordedClip: .init(
                    url: audioURL,
                    duration: 2,
                    volume: 0.4
                ),
                selectedTrack: .recorded
            ),
            presentation: .init(
                .corrections,
                socialVideoDestination: .tikTok,
                showsSafeAreaGuides: true
            )
        )

        viewModel.prepareEditingConfigurationForInitialLoad(
            editingConfiguration,
            videoPlayer: videoPlayer
        )

        var video = Video.mock
        viewModel.applyPendingEditingConfiguration(
            to: &video,
            containerSize: CGSize(width: 320, height: 240)
        )
        viewModel.currentVideo = video
        await viewModel.restorePendingEditingPresentationState()

        #expect(abs(videoPlayer.currentTime - 11) < 0.0001)
        #expect(viewModel.currentVideo?.rangeDuration == 8...24)
        #expect(abs(Double(viewModel.currentVideo?.rate ?? 0) - 1.5) < 0.0001)
        #expect(abs(Double(viewModel.currentVideo?.volume ?? 0) - 0.55) < 0.0001)
        #expect(viewModel.currentVideo?.rotation == 90)
        #expect(viewModel.currentVideo?.isMirror == true)
        #expect(viewModel.currentVideo?.audio?.url == audioURL)
        #expect(viewModel.selectedAudioTrack == .recorded)
        #expect(viewModel.cropFreeformRect == editingConfiguration.crop.freeformRect)
        #expect(viewModel.socialVideoDestination == .tikTok)
        #expect(viewModel.showsSafeAreaOverlay)
        #expect(viewModel.selectedTools == .corrections)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .cut) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .speed) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .presets) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .corrections) == true)
    }

    @Test
    func currentEditingConfigurationBuildsSnapshotFromCurrentEditorState() throws {
        let viewModel = EditorViewModel()
        let audioURL = try TestFixtures.createTemporaryAudio()
        defer { FileManager.default.removeIfExists(for: audioURL) }

        var video = Video.mock
        video.rangeDuration = 4...18
        video.updateRate(1.75)
        video.rotation = 180
        video.isMirror = true
        video.colorCorrection = .init(
            brightness: 0.2,
            contrast: 1.15,
            saturation: 0.65
        )
        video.audio = Audio(
            url: audioURL,
            duration: 2.5,
            volume: 0.45
        )

        viewModel.currentVideo = video
        viewModel.frames = VideoFrames(
            scaleValue: 0.3,
            frameColor: Color(uiColor: .systemOrange)
        )
        viewModel.selectedAudioTrack = .recorded
        viewModel.cropFreeformRect = .init(
            x: 0.12,
            y: 0.08,
            width: 0.72,
            height: 0.6
        )
        viewModel.socialVideoDestination = .youtubeShorts
        viewModel.showsSafeAreaOverlay = true
        viewModel.selectTool(.corrections)

        let configuration = viewModel.currentEditingConfiguration(currentTimelineTime: 9)

        #expect(configuration?.trim.lowerBound == 4)
        #expect(configuration?.trim.upperBound == 18)
        #expect(abs(Double(configuration?.playback.rate ?? 0) - 1.75) < 0.0001)
        #expect(abs(Double(configuration?.playback.currentTimelineTime ?? 0) - 9) < 0.0001)
        #expect(configuration?.crop.rotationDegrees == 180)
        #expect(configuration?.crop.isMirrored == true)
        #expect(configuration?.crop.freeformRect == viewModel.cropFreeformRect)
        #expect(abs((configuration?.corrections.brightness ?? 0) - 0.2) < 0.0001)
        #expect(configuration?.frame.colorToken == "palette:orange")
        #expect(configuration?.audio.selectedTrack == .recorded)
        #expect(configuration?.audio.recordedClip?.url == audioURL)
        #expect(configuration?.presentation.selectedTool == .corrections)
        #expect(configuration?.presentation.socialVideoDestination == .youtubeShorts)
        #expect(configuration?.presentation.showsSafeAreaGuides == true)
    }

    @Test
    func toggleSafeAreaOverlayTogglesTheSocialOverlayVisibility() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1080, height: 1920)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectSocialVideoDestination(.instagramReels)

        viewModel.toggleSafeAreaOverlay()

        #expect(viewModel.socialVideoDestination == .instagramReels)
        #expect(viewModel.showsSafeAreaOverlay == false)
        #expect(viewModel.shouldShowSafeAreaOverlay == false)
        #expect(viewModel.isCropFormatSelected(.vertical9x16))
    }

    @Test
    func restoredNonSocialPresetGeometryMapsBackToThePresetLibrary() async throws {
        let viewModel = EditorViewModel()
        let cropRect = try #require(
            VideoCropFormatPreset.square1x1.makeFreeformRect(
                for: CGSize(width: 1920, height: 1080)
            )
        )
        let editingConfiguration = VideoEditingConfiguration(
            crop: .init(
                freeformRect: cropRect
            ),
            presentation: .init(
                .presets
            )
        )
        let videoPlayer = VideoPlayerManager()

        viewModel.prepareEditingConfigurationForInitialLoad(
            editingConfiguration,
            videoPlayer: videoPlayer
        )

        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.applyPendingEditingConfiguration(
            to: &video,
            containerSize: CGSize(width: 320, height: 240)
        )
        viewModel.currentVideo = video
        await viewModel.restorePendingEditingPresentationState()

        #expect(viewModel.selectedCropPreset() == .square1x1)
        #expect(viewModel.selectedCropPresetBadgeTitle() == "1:1")
        #expect(viewModel.selectedCropPresetBadgeDimension() == "1:1")
        #expect(viewModel.socialVideoDestination == nil)
        #expect(viewModel.shouldUseCropPresetSpotlight)
    }

    @Test
    func closingPresetToolKeepsTheOverlayBadgeAndSafeAreaVisible() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1080, height: 1920)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectSocialVideoDestination(.tikTok)

        viewModel.closeSelectedTool()

        #expect(viewModel.selectedTools == nil)
        #expect(viewModel.shouldShowCropOverlay)
        #expect(viewModel.isCropOverlayInteractive == true)
        #expect(viewModel.shouldShowSafeAreaOverlay)
        #expect(viewModel.shouldShowCropPresetBadge())
        #expect(viewModel.shouldUseCropPresetSpotlight)
        #expect(viewModel.selectedCropPresetBadgeTitle() == "Social")
    }

    @Test
    func updateCurrentVideoLayoutUpdatesTheTrackedGeometry() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.geometrySize = CGSize(width: 200, height: 100)
        video.frameSize = CGSize(width: 200, height: 100)
        viewModel.currentVideo = video

        viewModel.updateCurrentVideoLayout(
            to: CGSize(width: 400, height: 200)
        )

        #expect(viewModel.currentVideo?.geometrySize == CGSize(width: 400, height: 200))
        #expect(viewModel.currentVideo?.frameSize == CGSize(width: 400, height: 200))
    }

}
