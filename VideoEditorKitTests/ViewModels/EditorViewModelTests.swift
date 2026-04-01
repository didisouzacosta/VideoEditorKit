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
    func refreshThumbnailsIfNeededKeepsTheLatestThumbnailRequestForTheSameVideo() async {
        let thumbnailProbe = ThumbnailLoaderProbe()
        let viewModel = EditorViewModel(
            .init(
                loadVideo: { await Video.load(from: $0) },
                makeThumbnails: { _, _, _ in
                    await thumbnailProbe.load()
                },
                sleep: { try await Task.sleep(for: $0) }
            )
        )
        var video = Video.mock
        video.thumbnailsImages = []
        viewModel.currentVideo = video

        viewModel.refreshThumbnailsIfNeeded(
            containerSize: CGSize(width: 300, height: 120)
        )
        viewModel.refreshThumbnailsIfNeeded(
            containerSize: CGSize(width: 420, height: 120)
        )

        await thumbnailProbe.resumeNext(
            with: [
                .init(image: TestFixtures.makeSolidImage(color: .systemRed))
            ]
        )
        await thumbnailProbe.resumeNext(
            with: [
                .init(image: TestFixtures.makeSolidImage(color: .systemGreen))
            ]
        )

        for _ in 0..<10 where viewModel.currentVideo?.thumbnailsImages.count != 1 {
            try? await Task.sleep(for: .milliseconds(10))
        }

        let resolvedImage = try? #require(viewModel.currentVideo?.thumbnailsImages.first?.image)
        let resolvedPixel = resolvedImage?.pngData()
        let expectedPixel = TestFixtures.makeSolidImage(color: .systemGreen).pngData()
        #expect(resolvedPixel == expectedPixel)
    }

    @Test
    func applyLoadedThumbnailsIgnoresResultsForAnotherVideo() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.thumbnailsImages = []
        viewModel.currentVideo = video

        viewModel.applyLoadedThumbnails(
            [
                .init(image: TestFixtures.makeSolidImage(color: .systemRed))
            ],
            for: .init(videoID: UUID(), generation: 0)
        )

        #expect(viewModel.currentVideo?.thumbnailsImages.isEmpty == true)
    }

    @Test
    func applyLoadedThumbnailsIgnoresStaleGenerations() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.thumbnailsImages = []
        viewModel.currentVideo = video

        viewModel.refreshThumbnailsIfNeeded(
            containerSize: CGSize(width: 300, height: 120)
        )
        viewModel.refreshThumbnailsIfNeeded(
            containerSize: CGSize(width: 420, height: 120)
        )

        viewModel.applyLoadedThumbnails(
            [
                .init(image: TestFixtures.makeSolidImage(color: .systemRed))
            ],
            for: .init(videoID: video.id, generation: 1)
        )

        #expect(viewModel.currentVideo?.thumbnailsImages.isEmpty == true)
    }

    @Test
    func exportVideoOnlyExistsWhileTheQualitySheetIsPresented() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock

        #expect(viewModel.exportVideo == nil)

        viewModel.presentationState.showVideoQualitySheet = true

        #expect(viewModel.exportVideo?.id == viewModel.currentVideo?.id)
    }

    @Test
    func handleRecordedVideoResetsTheSelectedAudioTrackAndLoadsThePlayer() {
        let viewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        let recordedVideoURL = URL(fileURLWithPath: "/tmp/recorded-video.mov")
        viewModel.presentationState.selectedAudioTrack = .recorded

        viewModel.handleRecordedVideo(recordedVideoURL, videoPlayer: videoPlayer)

        #expect(viewModel.presentationState.selectedAudioTrack == .video)
        #expect(videoPlayer.loadState == .loaded(recordedVideoURL))
    }

    @Test
    func setSourceVideoIfNeededBootstrapsTheFirstSourceOnlyOnce() async {
        let loadVideoProbe = LoadedVideoURLProbe()
        let viewModel = EditorViewModel(
            .init(
                loadVideo: { url in
                    await loadVideoProbe.record(url)
                    return Video(url: url, rangeDuration: 0...10)
                },
                makeThumbnails: { _, _, _ in [] },
                sleep: { try await Task.sleep(for: $0) }
            )
        )
        let videoPlayer = VideoPlayerManager()
        let firstURL = URL(fileURLWithPath: "/tmp/source-a.mp4")
        let secondURL = URL(fileURLWithPath: "/tmp/source-b.mp4")

        viewModel.setSourceVideoIfNeeded(
            firstURL,
            availableSize: CGSize(width: 390, height: 844),
            videoPlayer: videoPlayer
        )
        viewModel.setSourceVideoIfNeeded(
            secondURL,
            availableSize: CGSize(width: 390, height: 844),
            videoPlayer: videoPlayer
        )

        for _ in 0..<10 where await loadVideoProbe.urls().count != 1 {
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(await loadVideoProbe.urls() == [firstURL])
        #expect(videoPlayer.loadState == .loaded(firstURL))
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
    func setCorrectionsMutatesTheCurrentVideoImmediately() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        let correction = ColorCorrection(
            brightness: 0.2,
            contrast: -0.1,
            saturation: 0.35
        )

        viewModel.setCorrections(correction)

        #expect(viewModel.currentVideo?.colorCorrection == correction)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .corrections) == true)

        viewModel.setCorrections(.init())

        #expect(viewModel.currentVideo?.colorCorrection == .init())
        #expect(viewModel.currentVideo?.isAppliedTool(for: .corrections) == false)
    }

    @Test
    func settingTheSameCorrectionsDoesNotAdvanceTheEditingConfigurationRevision() {
        let viewModel = EditorViewModel()
        let correction = ColorCorrection(brightness: 0.2, contrast: -0.1, saturation: 0.35)
        var video = Video.mock
        video.colorCorrection = correction
        viewModel.currentVideo = video
        let initialRevision = viewModel.presentationState.editingConfigurationRevision

        viewModel.setCorrections(correction)

        #expect(viewModel.presentationState.editingConfigurationRevision == initialRevision)
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
        let cropSummary = viewModel.cropPresentationSummary

        #expect(cropSummary.selectedPreset == .original)
        #expect(cropSummary.isCropFormatSelected(.original))
        #expect(cropSummary.shouldUseCropPresetSpotlight == false)
    }

    @Test
    func selectingVerticalCropFormatCreatesACenteredNineBySixteenRect() throws {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)

        viewModel.selectCropFormat(.vertical9x16)

        let cropRect = try #require(viewModel.cropPresentationState.freeformRect)
        let cropSummary = viewModel.cropPresentationSummary
        #expect(abs(cropRect.x - 0.341796875) < 0.0001)
        #expect(abs(cropRect.width - 0.31640625) < 0.0001)
        #expect(abs(cropRect.y - 0) < 0.0001)
        #expect(abs(cropRect.height - 1) < 0.0001)
        #expect(viewModel.presentationState.selectedTool == nil)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .presets) == true)
        #expect(cropSummary.shouldShowCropOverlay)
        #expect(cropSummary.isCropOverlayInteractive)
        #expect(cropSummary.shouldUseCropPresetSpotlight)
        #expect(cropSummary.isCropFormatSelected(.vertical9x16))
        #expect(viewModel.cropPresentationState.socialVideoDestination == nil)
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay)
        #expect(cropSummary.shouldShowSafeAreaOverlay)
        #expect(cropSummary.activeSafeAreaGuideProfile == .universalSocial)
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
        let cropSummary = viewModel.cropPresentationSummary

        #expect(viewModel.cropPresentationState.freeformRect == nil)
        #expect(cropSummary.shouldShowCropOverlay == false)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .presets) == false)
        #expect(cropSummary.isCropFormatSelected(.original))
        #expect(viewModel.cropPresentationState.socialVideoDestination == nil)
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay == false)
        #expect(cropSummary.isCropOverlayInteractive)
        #expect(cropSummary.shouldUseCropPresetSpotlight == false)
        #expect(cropSummary.shouldShowCanvasResetButton == false)
        #expect(cropSummary.badgeTitle == "Original")
        #expect(cropSummary.badgeDimension == "1920x1080")
    }

    @Test
    func selectingVerticalCropFormatAlsoUpdatesTheCanvasEditorState() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)

        viewModel.selectCropFormat(.vertical9x16)

        #expect(viewModel.cropPresentationState.canvasEditorState.preset == .story)
        #expect(viewModel.cropPresentationState.canvasEditorState.transform == .identity)
        #expect(viewModel.cropPresentationState.canvasEditorState.showsSafeAreaOverlay)
    }

    @Test
    func selectingSocialVideoDestinationUpdatesIntentWithoutDependingOnGeometryInference() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1080, height: 1920)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)

        viewModel.selectSocialVideoDestination(.youtubeShorts)
        let cropSummary = viewModel.cropPresentationSummary

        #expect(viewModel.cropPresentationState.socialVideoDestination == .youtubeShorts)
        #expect(cropSummary.isCropFormatSelected(.vertical9x16))
        #expect(cropSummary.isSocialVideoDestinationSelected(.youtubeShorts))
        #expect(cropSummary.selectedPreset == .vertical9x16)
        #expect(cropSummary.badgeTitle == "Social")
        #expect(cropSummary.badgeDimension == "9:16")
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay)
    }

    @Test
    func activeSafeAreaGuideProfileMatchesTheSelectedDestination() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1080, height: 1920)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)

        viewModel.selectSocialVideoDestination(.youtubeShorts)

        #expect(viewModel.cropPresentationSummary.activeSafeAreaGuideProfile == .platform(.youtubeShorts))
    }

    @Test
    func safeAreaOverlayOnlyAppearsWhenTheGuideToggleIsEnabled() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1080, height: 1920)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectSocialVideoDestination(.tikTok)

        viewModel.cropPresentationState.showsSafeAreaOverlay = false

        #expect(viewModel.cropPresentationSummary.shouldShowSafeAreaOverlay == false)
        #expect(viewModel.cropPresentationSummary.activeSafeAreaGuideProfile == nil)
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

        let cropRect = try #require(viewModel.cropPresentationState.freeformRect)
        let cropSummary = viewModel.cropPresentationSummary
        #expect(abs(cropRect.x - 0.275) < 0.0001)
        #expect(abs(cropRect.width - 0.45) < 0.0001)
        #expect(viewModel.cropPresentationState.socialVideoDestination == nil)
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay == false)
        #expect(cropSummary.shouldUseCropPresetSpotlight)
        #expect(cropSummary.selectedPreset == .portrait4x5)
        #expect(cropSummary.badgeTitle == "Portrait")
        #expect(cropSummary.badgeDimension == "4:5")
        #expect(cropSummary.badgeText == "Portrait • 4:5")
    }

    @Test
    func currentEditingConfigurationPersistsActivePresetPresentationState() throws {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectCropFormat(.vertical9x16)

        let configuration = try #require(
            viewModel.currentEditingConfiguration(currentTimelineTime: 12)
        )
        let cropRect = try #require(configuration.crop.freeformRect)
        let activeRect = try #require(viewModel.cropPresentationState.freeformRect)

        #expect(configuration.presentation.socialVideoDestination == nil)
        #expect(configuration.presentation.showsSafeAreaGuides)
        #expect(configuration.playback.currentTimelineTime == 12)
        #expect(cropRect == activeRect)
        #expect(configuration.canvas.snapshot.preset == .story)
        #expect(configuration.canvas.snapshot.showsSafeAreaOverlay)
    }

    @Test
    func currentEditingConfigurationPersistsCanvasTransform() throws {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video
        viewModel.cropPresentationState.canvasEditorState.restore(
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
    func originalCanvasTransformShowsTheResetAffordanceAndCanBeReset() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1920, height: 1080)
        viewModel.currentVideo = video

        viewModel.cropPresentationState.canvasEditorState.restore(
            .init(
                preset: .original,
                transform: .init(
                    normalizedOffset: CGPoint(x: 0.16, y: -0.05),
                    zoom: 1.4
                )
            )
        )

        viewModel.handleCanvasPreviewChange()

        #expect(viewModel.cropPresentationSummary.shouldShowCanvasResetButton)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .presets) == true)

        viewModel.resetCanvasTransform()

        #expect(viewModel.cropPresentationState.canvasEditorState.transform == .identity)
        #expect(viewModel.cropPresentationSummary.shouldShowCanvasResetButton == false)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .presets) == false)
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

        #expect(viewModel.cropPresentationState.canvasEditorState.preset == .social(platform: .tiktok))
        #expect(viewModel.cropPresentationState.canvasEditorState.showsSafeAreaOverlay)
        #expect(viewModel.cropPresentationState.canvasEditorState.transform == .identity)
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

        #expect(viewModel.cropPresentationState.canvasEditorState.snapshot() == persistedSnapshot)
        #expect(viewModel.cropPresentationState.socialVideoDestination == .instagramReels)
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay == true)
    }

    @Test
    func genericSocialPresetCanStillToggleTheSafeAreaOverlay() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1080, height: 1920)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectCropFormat(.vertical9x16)

        viewModel.toggleSafeAreaOverlay()

        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay == false)
        #expect(viewModel.cropPresentationSummary.shouldShowSafeAreaOverlay == false)
        #expect(viewModel.cropPresentationSummary.activeSafeAreaGuideProfile == nil)
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
        #expect(viewModel.presentationState.selectedAudioTrack == .recorded)
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
        viewModel.presentationState.selectedAudioTrack = .recorded

        viewModel.removeAudio()

        #expect(FileManager.default.fileExists(atPath: audioURL.path()) == false)
        #expect(viewModel.currentVideo?.audio == nil)
        #expect(viewModel.presentationState.selectedAudioTrack == .video)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == false)
    }

    @Test
    func selectingRecordedTrackFallsBackToVideoWhenNoRecordedAudioExists() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock

        viewModel.selectAudioTrack(.recorded)

        #expect(viewModel.presentationState.selectedAudioTrack == .video)
    }

    @Test
    func updateSelectedTrackVolumeRemovesTheAudioToolWhenBackAtDefaults() {
        let viewModel = EditorViewModel()
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock
        video.appliedTool(for: .audio)
        viewModel.currentVideo = video
        viewModel.presentationState.selectedAudioTrack = .video

        viewModel.updateSelectedTrackVolume(1.0, videoPlayer: videoPlayer)

        #expect(abs(Double(viewModel.currentVideo?.volume ?? 0) - 1.0) < 0.0001)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == false)
    }

    @Test
    func editingConfigurationRevisionAdvancesWhenEditingStateMutates() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        let initialRevision = viewModel.presentationState.editingConfigurationRevision

        viewModel.selectTool(.corrections)
        viewModel.setCorrections(ColorCorrection(brightness: 0.2))

        #expect(viewModel.presentationState.editingConfigurationRevision > initialRevision)
    }

    @Test
    func frameEditsAdvanceTheEditingConfigurationRevision() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        let initialRevision = viewModel.presentationState.editingConfigurationRevision

        viewModel.setFrameColor(.red)
        viewModel.setFrameScale(0.35)

        #expect(viewModel.presentationState.editingConfigurationRevision >= initialRevision + 2)
    }

    @Test
    func reapplyingSpeedCancelsThePendingResetRemovalTask() async {
        let sleepProbe = DeferredSleepProbe()
        let viewModel = EditorViewModel(
            .init(
                loadVideo: { await Video.load(from: $0) },
                makeThumbnails: { video, containerSize, displayScale in
                    await video.makeThumbnails(
                        containerSize: containerSize,
                        displayScale: displayScale
                    )
                },
                sleep: { _ in
                    try await sleepProbe.sleep()
                    try Task.checkCancellation()
                }
            )
        )
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock
        video.rate = 2
        video.appliedTool(for: .speed)
        viewModel.currentVideo = video
        viewModel.selectTool(.speed)

        viewModel.reset(.speed, videoPlayer: videoPlayer)
        viewModel.updateRate(rate: 1.5)

        await sleepProbe.resumeNext()
        try? await Task.sleep(for: .milliseconds(10))

        #expect(abs(Double(viewModel.currentVideo?.rate ?? 0) - 1.5) < 0.0001)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .speed) == true)
    }

    @Test
    func selectToolIgnoresBlockedAndHiddenToolsFromAvailability() {
        let viewModel = EditorViewModel()
        viewModel.setToolAvailability([
            .init(.corrections),
            .init(.speed, access: .blocked),
        ])

        viewModel.selectTool(.corrections)
        #expect(viewModel.presentationState.selectedTool == .corrections)

        viewModel.selectTool(.speed)
        #expect(viewModel.presentationState.selectedTool == .corrections)

        viewModel.selectTool(.audio)
        #expect(viewModel.presentationState.selectedTool == .corrections)
    }

    @Test
    func changingAvailabilityClearsTheCurrentSelectionWhenItBecomesUnavailable() {
        let viewModel = EditorViewModel()
        viewModel.selectTool(.corrections)

        viewModel.setToolAvailability([
            .init(.speed),
            .init(.presets),
        ])

        #expect(viewModel.presentationState.selectedTool == nil)
    }

    @Test
    func frameEditsMutateTheSharedFramesState() throws {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock

        viewModel.setFrameColor(.red)
        viewModel.setFrameScale(0.35)

        #expect(SystemColorPalette.matches(viewModel.frames.frameColor, .red))
        #expect(abs(viewModel.frames.scaleValue - 0.35) < 0.0001)
        let persistedFrameColor = try #require(viewModel.currentVideo?.videoFrames?.frameColor)
        #expect(SystemColorPalette.matches(persistedFrameColor, .red))
        #expect(abs((viewModel.currentVideo?.videoFrames?.scaleValue ?? 0) - 0.35) < 0.0001)
    }

    @Test
    func settingTheSameFrameValuesDoesNotAdvanceTheEditingConfigurationRevision() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        viewModel.frames = .init(
            scaleValue: 0.35,
            frameColor: .red
        )
        viewModel.currentVideo?.videoFrames = viewModel.frames
        let initialRevision = viewModel.presentationState.editingConfigurationRevision

        viewModel.setFrameColor(.red)
        viewModel.setFrameScale(0.35)

        #expect(viewModel.presentationState.editingConfigurationRevision == initialRevision)
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

        #expect(viewModel.presentationState.selectedTool == nil)
        #expect(viewModel.presentationState.showVideoQualitySheet == false)

        for _ in 0..<10 where !viewModel.presentationState.showVideoQualitySheet {
            try? await Task.sleep(for: .milliseconds(100))
        }

        #expect(viewModel.presentationState.showVideoQualitySheet)
    }

    @Test
    func cancelDeferredTasksCancelsTheDeferredExporterPresentation() async {
        let sleepProbe = DeferredSleepProbe()
        let viewModel = EditorViewModel(
            .init(
                loadVideo: { await Video.load(from: $0) },
                makeThumbnails: { video, containerSize, displayScale in
                    await video.makeThumbnails(
                        containerSize: containerSize,
                        displayScale: displayScale
                    )
                },
                sleep: { _ in
                    try await sleepProbe.sleep()
                    try Task.checkCancellation()
                }
            )
        )

        viewModel.presentExporter()
        viewModel.cancelDeferredTasks()

        await sleepProbe.resumeNext()
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.presentationState.showVideoQualitySheet == false)
    }

    @Test
    func cancelDeferredTasksAlsoCancelsPendingToolResetRemoval() async {
        let sleepProbe = DeferredSleepProbe()
        let viewModel = EditorViewModel(
            .init(
                loadVideo: { await Video.load(from: $0) },
                makeThumbnails: { video, containerSize, displayScale in
                    await video.makeThumbnails(
                        containerSize: containerSize,
                        displayScale: displayScale
                    )
                },
                sleep: { _ in
                    try await sleepProbe.sleep()
                    try Task.checkCancellation()
                }
            )
        )
        let videoPlayer = VideoPlayerManager()
        var video = Video.mock
        video.rate = 2
        video.appliedTool(for: .speed)
        viewModel.currentVideo = video
        viewModel.selectTool(.speed)

        viewModel.reset(.speed, videoPlayer: videoPlayer)
        viewModel.cancelDeferredTasks()

        await sleepProbe.resumeNext()
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.currentVideo?.isAppliedTool(for: .speed) == true)
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
        #expect(viewModel.presentationState.selectedAudioTrack == .recorded)
        #expect(viewModel.cropPresentationState.freeformRect == editingConfiguration.crop.freeformRect)
        #expect(viewModel.cropPresentationState.socialVideoDestination == .tikTok)
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay)
        #expect(viewModel.presentationState.selectedTool == .corrections)
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
        viewModel.presentationState.selectedAudioTrack = .recorded
        viewModel.cropPresentationState.freeformRect = .init(
            x: 0.12,
            y: 0.08,
            width: 0.72,
            height: 0.6
        )
        viewModel.cropPresentationState.socialVideoDestination = .youtubeShorts
        viewModel.cropPresentationState.showsSafeAreaOverlay = true
        viewModel.selectTool(.corrections)

        let configuration = viewModel.currentEditingConfiguration(currentTimelineTime: 9)

        #expect(configuration?.trim.lowerBound == 4)
        #expect(configuration?.trim.upperBound == 18)
        #expect(abs(Double(configuration?.playback.rate ?? 0) - 1.75) < 0.0001)
        #expect(abs(Double(configuration?.playback.currentTimelineTime ?? 0) - 9) < 0.0001)
        #expect(configuration?.crop.rotationDegrees == 180)
        #expect(configuration?.crop.isMirrored == true)
        #expect(configuration?.crop.freeformRect == viewModel.cropPresentationState.freeformRect)
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

        #expect(viewModel.cropPresentationState.socialVideoDestination == .instagramReels)
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay == false)
        #expect(viewModel.cropPresentationSummary.shouldShowSafeAreaOverlay == false)
        #expect(viewModel.cropPresentationSummary.isCropFormatSelected(.vertical9x16))
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

        #expect(viewModel.cropPresentationSummary.selectedPreset == .square1x1)
        #expect(viewModel.cropPresentationSummary.badgeTitle == "Square")
        #expect(viewModel.cropPresentationSummary.badgeDimension == "1:1")
        #expect(viewModel.cropPresentationSummary.badgeText == "Square • 1:1")
        #expect(viewModel.cropPresentationState.socialVideoDestination == nil)
        #expect(viewModel.cropPresentationSummary.shouldUseCropPresetSpotlight)
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
        let cropSummary = viewModel.cropPresentationSummary

        #expect(viewModel.presentationState.selectedTool == nil)
        #expect(cropSummary.shouldShowCropOverlay)
        #expect(cropSummary.isCropOverlayInteractive == true)
        #expect(cropSummary.shouldShowSafeAreaOverlay)
        #expect(cropSummary.shouldShowCropPresetBadge)
        #expect(cropSummary.shouldUseCropPresetSpotlight)
        #expect(cropSummary.badgeTitle == "Social")
        #expect(cropSummary.badgeText == "Social • 9:16")
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

    @Test
    func updateCurrentVideoLayoutDoesNotAdvanceTheEditingConfigurationRevision() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.geometrySize = CGSize(width: 200, height: 100)
        video.frameSize = CGSize(width: 200, height: 100)
        viewModel.currentVideo = video
        let initialRevision = viewModel.presentationState.editingConfigurationRevision

        viewModel.updateCurrentVideoLayout(
            to: CGSize(width: 400, height: 200)
        )

        #expect(viewModel.presentationState.editingConfigurationRevision == initialRevision)
    }

}

private actor DeferredSleepProbe {

    // MARK: - Private Properties

    private var continuations = [CheckedContinuation<Void, any Error>]()

    // MARK: - Public Methods

    func sleep() async throws {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeNext() {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume()
    }

}

private actor ThumbnailLoaderProbe {

    // MARK: - Private Properties

    private var continuations = [CheckedContinuation<[ThumbnailImage], Never>]()

    // MARK: - Public Methods

    func load() async -> [ThumbnailImage] {
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeNext(
        with thumbnails: [ThumbnailImage]
    ) {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume(returning: thumbnails)
    }

}

private actor LoadedVideoURLProbe {

    // MARK: - Private Properties

    private var recordedURLs = [URL]()

    // MARK: - Public Methods

    func record(_ url: URL) {
        recordedURLs.append(url)
    }

    func urls() -> [URL] {
        recordedURLs
    }

}
