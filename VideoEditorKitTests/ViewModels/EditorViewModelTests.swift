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
    func setTranscriptDocumentRemapsThePersistedTimelineToTheCurrentVideoState() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.rangeDuration = 20...80
        video.updateRate(2)
        viewModel.currentVideo = video

        viewModel.setTranscriptDocument(
            TranscriptDocument(
                segments: [
                    EditableTranscriptSegment(
                        id: UUID(),
                        timeMapping: .init(
                            sourceStartTime: 10,
                            sourceEndTime: 40,
                            timelineStartTime: 10,
                            timelineEndTime: 40
                        ),
                        originalText: "Original segment",
                        editedText: "Edited segment"
                    )
                ]
            )
        )

        #expect(viewModel.transcriptFeatureState == .loaded)
        #expect(viewModel.transcriptDocument?.segments.first?.timeMapping.timelineRange == 10...20)
    }

    @Test
    func transcribeCurrentVideoMapsProviderOutputIntoTheEditableTranscriptDocument() async {
        let provider = RecordingTranscriptionProvider(
            result: .success(
                VideoTranscriptionResult(
                    segments: [
                        TranscriptionSegment(
                            id: UUID(),
                            startTime: 8,
                            endTime: 12,
                            text: "Ola mundo",
                            words: [
                                TranscriptionWord(
                                    id: UUID(),
                                    startTime: 8,
                                    endTime: 9,
                                    text: "Ola"
                                )
                            ]
                        )
                    ]
                )
            )
        )
        let style = TranscriptStyle(
            id: UUID(),
            name: "Classic",
            fontFamily: "Avenir"
        )
        let viewModel = EditorViewModel()
        var video = Video(url: URL(fileURLWithPath: "/tmp/transcription-source.mov"), rangeDuration: 0...20)
        video.updateRate(2)
        viewModel.currentVideo = video
        viewModel.configureTranscription(
            provider: provider,
            availableStyles: [style],
            preferredLocale: "pt-BR"
        )

        viewModel.transcribeCurrentVideo()
        await waitForTranscriptState(on: viewModel, equals: .loaded)

        let recordedInput = await provider.inputs().first
        #expect(recordedInput?.assetIdentifier == video.url.absoluteString)
        #expect(recordedInput?.preferredLocale == "pt-BR")
        #expect(viewModel.transcriptState == .loaded)
        #expect(viewModel.transcriptFeatureState == .loaded)
        #expect(viewModel.transcriptDocument?.availableStyles == [style])
        #expect(viewModel.transcriptDocument?.segments.first?.originalText == "Ola mundo")
        #expect(viewModel.transcriptDocument?.segments.first?.editedText == "Ola mundo")
        #expect(viewModel.transcriptDocument?.segments.first?.timeMapping.timelineRange == 4...6)
        #expect(viewModel.transcriptDocument?.segments.first?.words.first?.editedText == "Ola")
    }

    @Test
    func transcribeCurrentVideoFailsWhenProviderIsNotConfigured() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video(
            url: URL(fileURLWithPath: "/tmp/transcription-source.mov"),
            rangeDuration: 0...20
        )

        viewModel.transcribeCurrentVideo()

        #expect(viewModel.transcriptState == .failed(.providerNotConfigured))
        #expect(viewModel.transcriptFeatureState == .failed)
        #expect(viewModel.transcriptDocument == nil)
    }

    @Test
    func configureTranscriptionExposesAvailabilityImmediately() {
        let viewModel = EditorViewModel()

        #expect(viewModel.isTranscriptionAvailable == false)

        viewModel.configureTranscription(
            provider: RecordingTranscriptionProvider(
                result: .success(
                    VideoTranscriptionResult(segments: [])
                )
            )
        )

        #expect(viewModel.isTranscriptionAvailable)

        viewModel.configureTranscription(provider: nil)

        #expect(viewModel.isTranscriptionAvailable == false)
    }

    @Test
    func transcribeCurrentVideoFailsWhenProviderReturnsAnEmptyResult() async {
        let provider = RecordingTranscriptionProvider(
            result: .success(
                VideoTranscriptionResult(segments: [])
            )
        )
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video(
            url: URL(fileURLWithPath: "/tmp/transcription-source.mov"),
            rangeDuration: 0...20
        )
        viewModel.configureTranscription(provider: provider)

        viewModel.transcribeCurrentVideo()
        await waitForTranscriptFailure(on: viewModel)

        #expect(viewModel.transcriptState == .failed(.emptyResult))
        #expect(viewModel.transcriptFeatureState == .failed)
    }

    @Test
    func transcribeCurrentVideoMapsProviderFailuresIntoTranscriptState() async {
        let provider = RecordingTranscriptionProvider(
            result: .failure(.offline)
        )
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video(
            url: URL(fileURLWithPath: "/tmp/transcription-source.mov"),
            rangeDuration: 0...20
        )
        viewModel.configureTranscription(provider: provider)

        viewModel.transcribeCurrentVideo()
        await waitForTranscriptFailure(on: viewModel)

        #expect(
            viewModel.transcriptState
                == .failed(.providerFailure(message: TranscriptProviderProbeError.offline.localizedDescription))
        )
        #expect(viewModel.transcriptFeatureState == .failed)
    }

    @Test
    func updateTranscriptSegmentTextPreservesTimingAndOriginalText() {
        let viewModel = EditorViewModel()
        let segmentID = UUID()
        viewModel.setTranscriptDocument(
            TranscriptDocument(
                segments: [
                    EditableTranscriptSegment(
                        id: segmentID,
                        timeMapping: .init(
                            sourceStartTime: 10,
                            sourceEndTime: 14,
                            timelineStartTime: 5,
                            timelineEndTime: 7
                        ),
                        originalText: "Original segment",
                        editedText: "Original segment"
                    )
                ]
            )
        )

        viewModel.updateTranscriptSegmentText(
            "Edited segment",
            segmentID: segmentID
        )

        #expect(viewModel.transcriptDocument?.segments.first?.originalText == "Original segment")
        #expect(viewModel.transcriptDocument?.segments.first?.editedText == "Edited segment")
        #expect(viewModel.transcriptDocument?.segments.first?.timeMapping.sourceRange == 10...14)
        #expect(viewModel.transcriptDocument?.segments.first?.timeMapping.timelineRange == 5...7)
    }

    @Test
    func updateTranscriptSegmentStyleAssignsTheSegmentStyleWithoutChangingItsText() {
        let viewModel = EditorViewModel()
        let styleID = UUID()
        let segmentID = UUID()
        viewModel.setTranscriptDocument(
            TranscriptDocument(
                segments: [
                    EditableTranscriptSegment(
                        id: segmentID,
                        timeMapping: .init(
                            sourceStartTime: 10,
                            sourceEndTime: 14,
                            timelineStartTime: 5,
                            timelineEndTime: 7
                        ),
                        originalText: "Original segment",
                        editedText: "Edited segment"
                    )
                ],
                availableStyles: [
                    TranscriptStyle(
                        id: styleID,
                        name: "Classic",
                        fontFamily: "Avenir"
                    )
                ]
            )
        )

        viewModel.updateTranscriptSegmentStyle(
            styleID,
            segmentID: segmentID
        )

        #expect(viewModel.transcriptDocument?.segments.first?.styleID == styleID)
        #expect(viewModel.transcriptDocument?.segments.first?.editedText == "Edited segment")
    }

    @Test
    func resetTranscriptClearsTheDocumentAndReturnsToIdleState() {
        let viewModel = EditorViewModel()
        viewModel.setTranscriptDocument(
            TranscriptDocument(
                segments: [
                    EditableTranscriptSegment(
                        id: UUID(),
                        timeMapping: .init(
                            sourceStartTime: 10,
                            sourceEndTime: 14,
                            timelineStartTime: 5,
                            timelineEndTime: 7
                        ),
                        originalText: "Original segment",
                        editedText: "Edited segment"
                    )
                ]
            )
        )

        viewModel.resetTranscript()

        #expect(viewModel.transcriptDocument == nil)
        #expect(viewModel.transcriptFeatureState == .idle)
        #expect(viewModel.transcriptState == .idle)
    }

    @Test
    func updateTranscriptOverlayControlsPersistPositionAndSizeWithoutTouchingSelectionState() {
        let viewModel = EditorViewModel()
        viewModel.setTranscriptDocument(
            TranscriptDocument(
                segments: [
                    EditableTranscriptSegment(
                        id: UUID(),
                        timeMapping: .init(
                            sourceStartTime: 10,
                            sourceEndTime: 14,
                            timelineStartTime: 5,
                            timelineEndTime: 7
                        ),
                        originalText: "Original segment",
                        editedText: "Edited segment"
                    )
                ]
            )
        )
        viewModel.setTranscriptOverlaySelection(true)

        viewModel.updateTranscriptOverlayPosition(.top)
        viewModel.updateTranscriptOverlaySize(.large)

        #expect(viewModel.transcriptDocument?.overlayPosition == .top)
        #expect(viewModel.transcriptDocument?.overlaySize == .large)
        #expect(viewModel.presentationState.isTranscriptOverlaySelected)
    }

    @Test
    func activeTranscriptSegmentUsesTimelineTimingInsteadOfSourceTiming() {
        let viewModel = EditorViewModel()
        viewModel.setTranscriptDocument(
            TranscriptDocument(
                segments: [
                    EditableTranscriptSegment(
                        id: UUID(),
                        timeMapping: .init(
                            sourceStartTime: 20,
                            sourceEndTime: 40,
                            timelineStartTime: 10,
                            timelineEndTime: 20
                        ),
                        originalText: "Visible segment",
                        editedText: "Visible segment"
                    )
                ]
            )
        )

        #expect(viewModel.activeTranscriptSegment(at: 15)?.editedText == "Visible segment")
        #expect(viewModel.activeTranscriptSegment(at: 5) == nil)
    }

    @Test
    func updateRateRemapsTranscriptDocumentUsingTheCurrentTrim() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.rangeDuration = 20...80
        video.updateRate(1)
        viewModel.currentVideo = video
        viewModel.setTranscriptDocument(
            TranscriptDocument(
                segments: [
                    EditableTranscriptSegment(
                        id: UUID(),
                        timeMapping: .init(
                            sourceStartTime: 20,
                            sourceEndTime: 40,
                            timelineStartTime: 20,
                            timelineEndTime: 40
                        ),
                        originalText: "Original segment",
                        editedText: "Edited segment"
                    )
                ]
            )
        )

        viewModel.updateRate(rate: 2)

        #expect(abs(Double(viewModel.currentVideo?.rate ?? 0) - 2) < 0.0001)
        #expect(viewModel.transcriptDocument?.segments.first?.timeMapping.timelineRange == 10...20)
    }

    @Test
    func setCutRemapsTranscriptDocumentAndHidesSegmentsOutsideTheTrimmedRange() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.rangeDuration = 0...250
        viewModel.currentVideo = video
        viewModel.setTranscriptDocument(
            TranscriptDocument(
                segments: [
                    EditableTranscriptSegment(
                        id: UUID(),
                        timeMapping: .init(
                            sourceStartTime: 30,
                            sourceEndTime: 50,
                            timelineStartTime: 30,
                            timelineEndTime: 50
                        ),
                        originalText: "Visible",
                        editedText: "Visible"
                    ),
                    EditableTranscriptSegment(
                        id: UUID(),
                        timeMapping: .init(
                            sourceStartTime: 5,
                            sourceEndTime: 10,
                            timelineStartTime: 5,
                            timelineEndTime: 10
                        ),
                        originalText: "Hidden",
                        editedText: "Hidden"
                    ),
                ]
            )
        )
        viewModel.currentVideo?.rangeDuration = 20...60

        viewModel.setCut()

        #expect(viewModel.transcriptDocument?.segments.first?.timeMapping.timelineRange == 30...50)
        #expect(viewModel.transcriptDocument?.segments.last?.timeMapping.timelineRange == nil)
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
    func setAdjustsAppliesAndRemovesTheAdjustsTool() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        viewModel.selectTool(.adjusts)

        viewModel.setAdjusts(
            ColorAdjusts(brightness: 0.2, contrast: 0.15, saturation: 0.1)
        )

        #expect(abs((viewModel.currentVideo?.colorAdjusts.brightness ?? 0) - 0.2) < 0.0001)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .adjusts) == true)

        viewModel.setAdjusts(.init())

        #expect(viewModel.currentVideo?.colorAdjusts == .init())
        #expect(viewModel.currentVideo?.isAppliedTool(for: .adjusts) == false)
    }

    @Test
    func setAdjustsMutatesTheCurrentVideoImmediately() {
        let viewModel = EditorViewModel()
        viewModel.currentVideo = Video.mock
        let adjusts = ColorAdjusts(
            brightness: 0.2,
            contrast: -0.1,
            saturation: 0.35
        )

        viewModel.setAdjusts(adjusts)

        #expect(viewModel.currentVideo?.colorAdjusts == adjusts)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .adjusts) == true)

        viewModel.setAdjusts(.init())

        #expect(viewModel.currentVideo?.colorAdjusts == .init())
        #expect(viewModel.currentVideo?.isAppliedTool(for: .adjusts) == false)
    }

    @Test
    func settingTheSameAdjustsDoesNotAdvanceTheEditingConfigurationRevision() {
        let viewModel = EditorViewModel()
        let adjusts = ColorAdjusts(brightness: 0.2, contrast: -0.1, saturation: 0.35)
        var video = Video.mock
        video.colorAdjusts = adjusts
        viewModel.currentVideo = video
        let initialRevision = viewModel.presentationState.editingConfigurationRevision

        viewModel.setAdjusts(adjusts)

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
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay == false)
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
        #expect(viewModel.cropPresentationState.canvasEditorState.showsSafeAreaOverlay == false)
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
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay == false)
    }

    @Test
    func socialPresetIgnoresLegacySafeAreaStateWhenRenderingSummary() {
        let viewModel = EditorViewModel()
        var video = Video.mock
        video.presentationSize = CGSize(width: 1080, height: 1920)
        viewModel.currentVideo = video
        viewModel.selectTool(.presets)
        viewModel.selectSocialVideoDestination(.tikTok)

        viewModel.cropPresentationState.showsSafeAreaOverlay = false

        #expect(viewModel.cropPresentationSummary.shouldShowCropPresetBadge)
        #expect(viewModel.cropPresentationSummary.badgeText == "Social • 9:16")
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
        #expect(configuration.presentation.showsSafeAreaGuides == false)
        #expect(configuration.playback.currentTimelineTime == 12)
        #expect(cropRect == activeRect)
        #expect(configuration.canvas.snapshot.preset == .story)
        #expect(configuration.canvas.snapshot.showsSafeAreaOverlay == false)
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
        #expect(viewModel.cropPresentationState.canvasEditorState.showsSafeAreaOverlay == false)
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
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay == false)
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

        viewModel.selectTool(.adjusts)
        viewModel.setAdjusts(ColorAdjusts(brightness: 0.2))

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
            .init(.adjusts),
            .init(.speed, access: .blocked),
        ])

        viewModel.selectTool(.adjusts)
        #expect(viewModel.presentationState.selectedTool == .adjusts)

        viewModel.selectTool(.speed)
        #expect(viewModel.presentationState.selectedTool == .adjusts)

        viewModel.selectTool(.audio)
        #expect(viewModel.presentationState.selectedTool == .adjusts)
    }

    @Test
    func changingAvailabilityClearsTheCurrentSelectionWhenItBecomesUnavailable() {
        let viewModel = EditorViewModel()
        viewModel.selectTool(.adjusts)

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
        viewModel.selectTool(.adjusts)

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
        let transcriptSegmentID = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))

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
            adjusts: .init(
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
            transcript: .init(
                featureState: .loaded,
                document: TranscriptDocument(
                    segments: [
                        EditableTranscriptSegment(
                            id: transcriptSegmentID,
                            timeMapping: .init(
                                sourceStartTime: 6,
                                sourceEndTime: 18,
                                timelineStartTime: nil,
                                timelineEndTime: nil
                            ),
                            originalText: "Original segment",
                            editedText: "Edited segment"
                        )
                    ]
                )
            ),
            presentation: .init(
                .adjusts,
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
        #expect(viewModel.cropPresentationState.showsSafeAreaOverlay == false)
        #expect(viewModel.presentationState.selectedTool == .adjusts)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .cut) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .speed) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .presets) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .audio) == true)
        #expect(viewModel.currentVideo?.isAppliedTool(for: .adjusts) == true)
        #expect(viewModel.transcriptFeatureState == .loaded)
        #expect(viewModel.transcriptDocument?.segments.first?.id == transcriptSegmentID)
        #expect(
            viewModel.transcriptDocument?.segments.first?.timeMapping.timelineRange
                == 5.333333333333333...12.0
        )
    }

    @Test
    func currentEditingConfigurationBuildsSnapshotFromCurrentEditorState() throws {
        let viewModel = EditorViewModel()
        let audioURL = try TestFixtures.createTemporaryAudio()
        defer { FileManager.default.removeIfExists(for: audioURL) }
        let transcriptDocument = TranscriptDocument(
            segments: [
                EditableTranscriptSegment(
                    id: UUID(),
                    timeMapping: .init(
                        sourceStartTime: 10,
                        sourceEndTime: 18,
                        timelineStartTime: 10,
                        timelineEndTime: 18
                    ),
                    originalText: "Original segment",
                    editedText: "Edited segment"
                )
            ]
        )

        var video = Video.mock
        video.rangeDuration = 4...18
        video.updateRate(1.75)
        video.rotation = 180
        video.isMirror = true
        video.colorAdjusts = .init(
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
        viewModel.transcriptFeatureState = .loaded
        viewModel.transcriptDocument = transcriptDocument
        viewModel.cropPresentationState.socialVideoDestination = .youtubeShorts
        viewModel.cropPresentationState.showsSafeAreaOverlay = true
        viewModel.selectTool(.adjusts)

        let configuration = viewModel.currentEditingConfiguration(currentTimelineTime: 9)

        #expect(configuration?.trim.lowerBound == 4)
        #expect(configuration?.trim.upperBound == 18)
        #expect(abs(Double(configuration?.playback.rate ?? 0) - 1.75) < 0.0001)
        #expect(abs(Double(configuration?.playback.currentTimelineTime ?? 0) - 9) < 0.0001)
        #expect(configuration?.crop.rotationDegrees == 180)
        #expect(configuration?.crop.isMirrored == true)
        #expect(configuration?.crop.freeformRect == viewModel.cropPresentationState.freeformRect)
        #expect(abs((configuration?.adjusts.brightness ?? 0) - 0.2) < 0.0001)
        #expect(configuration?.frame.colorToken == "palette:orange")
        #expect(configuration?.audio.selectedTrack == .recorded)
        #expect(configuration?.audio.recordedClip?.url == audioURL)
        #expect(configuration?.transcript.featureState == .loaded)
        #expect(configuration?.transcript.document == transcriptDocument)
        #expect(configuration?.presentation.selectedTool == .adjusts)
        #expect(configuration?.presentation.socialVideoDestination == .youtubeShorts)
        #expect(configuration?.presentation.showsSafeAreaGuides == false)
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

private actor RecordingTranscriptionProvider: VideoTranscriptionProvider {

    // MARK: - Private Properties

    private let result: Result<VideoTranscriptionResult, TranscriptProviderProbeError>
    private var recordedInputs = [VideoTranscriptionInput]()

    // MARK: - Initializer

    init(result: Result<VideoTranscriptionResult, TranscriptProviderProbeError>) {
        self.result = result
    }

    // MARK: - Public Methods

    func transcribeVideo(input: VideoTranscriptionInput) async throws -> VideoTranscriptionResult {
        recordedInputs.append(input)
        return try result.get()
    }

    func inputs() -> [VideoTranscriptionInput] {
        recordedInputs
    }

}

private enum TranscriptProviderProbeError: LocalizedError {
    case offline

    var errorDescription: String? {
        switch self {
        case .offline:
            "offline"
        }
    }
}

@MainActor
private func waitForTranscriptState(
    on viewModel: EditorViewModel,
    equals expectedState: TranscriptFeatureState
) async {
    for _ in 0..<20 {
        if viewModel.transcriptState == expectedState {
            return
        }

        try? await Task.sleep(for: .milliseconds(10))
    }
}

@MainActor
private func waitForTranscriptFailure(on viewModel: EditorViewModel) async {
    for _ in 0..<20 {
        if case .failed = viewModel.transcriptState {
            return
        }

        try? await Task.sleep(for: .milliseconds(10))
    }
}
