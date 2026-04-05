//
//  EditorViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class EditorViewModel {

    struct Dependencies {

        // MARK: - Public Properties

        static let live = Self(
            loadVideo: { await Video.load(from: $0) },
            makeThumbnails: { video, containerSize, displayScale in
                await video.makeThumbnails(
                    containerSize: containerSize,
                    displayScale: displayScale
                )
            },
            sleep: { try await Task.sleep(for: $0) }
        )

        let loadVideo: @Sendable (URL) async -> Video
        let makeThumbnails: @Sendable (Video, CGSize, CGFloat) async -> [ThumbnailImage]
        let sleep: @Sendable (Duration) async throws -> Void

    }

    struct ThumbnailLoadRequest: Equatable, Sendable {

        // MARK: - Public Properties

        let videoID: UUID
        let generation: Int

    }

    private enum Constants {
        static let numericTolerance = 0.001
        static let exportPresentationDelay = Duration.milliseconds(200)
        static let toolResetDelay = Duration.milliseconds(100)
    }

    // MARK: - Public Properties

    let presentationState = EditorPresentationState()
    let cropPresentationState = EditorCropPresentationState()

    var currentVideo: Video?
    var frames = VideoFrames()
    var transcriptState: TranscriptFeatureState = .idle
    var transcriptFeatureState: TranscriptFeaturePersistenceState = .idle
    var transcriptDocument: TranscriptDocument?

    var hasCurrentVideo: Bool {
        currentVideo != nil
    }

    var exportVideo: Video? {
        EditorSessionCoordinator.exportVideo(
            currentVideo: currentVideo,
            isQualitySheetPresented: presentationState.showVideoQualitySheet
        )
    }

    var isMirrorEnabled: Bool {
        currentVideo?.isMirror ?? false
    }

    var cropRotation: Double {
        get { currentVideo?.rotation ?? 0 }
        set { setRotation(newValue) }
    }

    var cropPresentationSummary: EditorCropPresentationSummary {
        cropPresentationSummary()
    }

    // MARK: - Public Methods

    func cropPresentationSummary(
        isPlaybackFocused: Bool = false
    ) -> EditorCropPresentationSummary {
        EditorCropPresentationResolver.makeSummary(
            state: cropEditingState,
            video: currentVideo,
            fallbackContainerSize: lastPlayerContainerSize,
            isPlaybackFocused: isPlaybackFocused
        )
    }

    // MARK: - Private Properties

    private let dependencies: Dependencies
    private let taskCoordinator: EditorTaskCoordinator

    private var availableTranscriptStyles = [TranscriptStyle]()
    private var enabledTools = Set(ToolEnum.all)
    private var hasLoadedSourceVideo = false
    private var lastPlayerContainerSize = CGSize(width: 1, height: 220)
    private var lastThumbnailDisplayScale: CGFloat = 1
    private var pendingEditingConfiguration: VideoEditingConfiguration?
    private var preferredTranscriptLocale: String?
    private var transcriptionProvider: (any VideoTranscriptionProvider)?

    // MARK: - Initializer

    init(_ dependencies: Dependencies = .live) {
        self.dependencies = dependencies
        taskCoordinator = EditorTaskCoordinator(dependencies.sleep)
    }

    // MARK: - Public Methods

    func setNewVideo(_ url: URL, containerSize: CGSize) {
        invalidateThumbnailRequests()
        taskCoordinator.cancelTranscriptionTask()
        cancelPendingToolResetTasks()
        currentVideo = nil
        lastPlayerContainerSize = containerSize
        syncTranscriptRuntimeState()

        taskCoordinator.replaceLoadVideoTask { [weak self] in
            guard let self else { return }

            var video = await dependencies.loadVideo(url)
            guard !Task.isCancelled else { return }

            applyPendingEditingConfiguration(
                to: &video,
                containerSize: containerSize
            )

            frames = video.videoFrames ?? VideoFrames()
            currentVideo = video
            remapTranscriptDocumentIfNeeded()

            await self.restorePendingEditingPresentationState()

            loadThumbnails(
                for: video,
                containerSize: containerSize,
                displayScale: self.lastThumbnailDisplayScale
            )
            markEditingConfigurationChanged()
        }
    }

    func setToolAvailability(_ tools: [ToolAvailability]) {
        enabledTools = EditorToolSelectionCoordinator.enabledTools(
            from: tools
        )

        let previousSelection = presentationState.selectedTool
        presentationState.selectedTool = EditorToolSelectionCoordinator.resolvedSelection(
            currentSelection: presentationState.selectedTool,
            enabledTools: enabledTools
        )

        if previousSelection != presentationState.selectedTool {
            markEditingConfigurationChanged()
        }
    }

    func refreshThumbnailsIfNeeded(
        containerSize: CGSize,
        displayScale: CGFloat = 1
    ) {
        lastPlayerContainerSize = containerSize
        lastThumbnailDisplayScale = displayScale

        guard let video = currentVideo else { return }
        guard containerSize.width > 0, containerSize.height > 0 else { return }

        let expectedCount = video.thumbnailCount(for: containerSize)

        guard expectedCount > 0 else { return }

        let expectedThumbnailWidth = max(
            (containerSize.width / CGFloat(expectedCount)) * max(displayScale, 1),
            1
        )

        let isMissingThumbnails = video.thumbnailsImages.isEmpty
        let needsResize = video.thumbnailsImages.count != expectedCount
        let hasLowResolutionThumbnails =
            (video.thumbnailsImages.first?.image?.size.width ?? 0) < expectedThumbnailWidth

        guard isMissingThumbnails || needsResize || hasLowResolutionThumbnails else { return }

        loadThumbnails(
            for: video,
            containerSize: containerSize,
            displayScale: displayScale
        )
    }

    // MARK: - Private Methods

    private func loadThumbnails(
        for video: Video,
        containerSize: CGSize,
        displayScale: CGFloat
    ) {
        let request = taskCoordinator.makeThumbnailLoadRequest(
            for: video.id
        )

        taskCoordinator.runThumbnailLoad(
            request: request,
            operation: { [dependencies] in
                await dependencies.makeThumbnails(video, containerSize, displayScale)
            },
            apply: { [weak self] thumbnails, request in
                self?.applyLoadedThumbnails(
                    thumbnails,
                    for: request
                )
            }
        )
    }

    func applyLoadedThumbnails(
        _ thumbnails: [ThumbnailImage],
        for request: ThumbnailLoadRequest
    ) {
        guard
            taskCoordinator.acceptsThumbnailLoadRequest(
                request,
                currentVideoID: currentVideo?.id
            )
        else { return }

        currentVideo?.thumbnailsImages = thumbnails
    }

    private func invalidateThumbnailRequests() {
        taskCoordinator.cancelThumbnailRequests()
    }

    private func cancelPendingToolReset(
        for tool: ToolEnum
    ) {
        taskCoordinator.cancelPendingToolReset(for: tool)
    }

    private func cancelPendingToolResetTasks() {
        taskCoordinator.cancelPendingToolResetTasks()
    }

    private func schedulePendingToolReset(
        for tool: ToolEnum
    ) {
        taskCoordinator.schedulePendingToolReset(
            for: tool,
            after: Constants.toolResetDelay
        ) { [weak self] in
            guard let self else { return }

            currentVideo?.removeTool(for: tool)
            markEditingConfigurationChanged()
        }
    }

    func setFrameColor(_ color: Color) {
        guard EditorAppearanceEditingCoordinator.setFrameColor(color, in: &frames) else { return }
        syncFramesState()
    }

    func setFrameScale(_ scaleValue: Double) {
        guard EditorAppearanceEditingCoordinator.setFrameScale(scaleValue, in: &frames) else { return }
        syncFramesState()
    }

    func setAdjusts(_ adjusts: ColorAdjusts) {
        guard var currentVideo else { return }
        cancelPendingToolReset(for: .adjusts)

        guard
            EditorAppearanceEditingCoordinator.setAdjusts(
                adjusts,
                in: &currentVideo
            )
        else { return }

        self.currentVideo = currentVideo
        remapTranscriptDocumentIfNeeded()
        markEditingConfigurationChanged()
    }

    func updateRate(rate: Float) {
        cancelPendingToolReset(for: .speed)
        guard var currentVideo else { return }

        EditorPlaybackEditingCoordinator.updateRate(
            rate,
            in: &currentVideo,
            selectedTool: presentationState.selectedTool
        )
        self.currentVideo = currentVideo
        remapTranscriptDocumentIfNeeded()
        markEditingConfigurationChanged()
    }

    func setCut() {
        guard var currentVideo else { return }
        cancelPendingToolReset(for: .cut)

        EditorPlaybackEditingCoordinator.syncCutToolState(
            in: &currentVideo,
            tolerance: Constants.numericTolerance
        )
        self.currentVideo = currentVideo
        remapTranscriptDocumentIfNeeded()
        markEditingConfigurationChanged()
    }

    func resetCut() {
        cancelPendingToolReset(for: .cut)
        guard var currentVideo else { return }

        EditorPlaybackEditingCoordinator.resetCut(
            in: &currentVideo
        )
        self.currentVideo = currentVideo
        remapTranscriptDocumentIfNeeded()
        markEditingConfigurationChanged()
    }

    func rotate() {
        cancelPendingToolReset(for: .presets)
        guard var currentVideo else { return }

        EditorPlaybackEditingCoordinator.rotate(
            in: &currentVideo,
            selectedTool: presentationState.selectedTool
        )
        self.currentVideo = currentVideo
        markEditingConfigurationChanged()
    }

    func setRotation(_ rotation: Double) {
        cancelPendingToolReset(for: .presets)
        guard var currentVideo else { return }
        guard
            EditorPlaybackEditingCoordinator.setRotation(
                rotation,
                in: &currentVideo,
                selectedTool: presentationState.selectedTool
            )
        else { return }

        self.currentVideo = currentVideo
        markEditingConfigurationChanged()
    }

    func toggleMirror() {
        cancelPendingToolReset(for: .presets)
        guard var currentVideo else { return }

        EditorPlaybackEditingCoordinator.toggleMirror(
            in: &currentVideo,
            selectedTool: presentationState.selectedTool
        )
        self.currentVideo = currentVideo
        markEditingConfigurationChanged()
    }

    func setCropFreeformRect(_ rect: VideoEditingConfiguration.FreeformRect?) {
        guard cropPresentationState.freeformRect != rect else { return }
        cancelPendingToolReset(for: .presets)
        cropPresentationState.freeformRect = rect
        syncCropToolState()
        markEditingConfigurationChanged()
    }

    func selectCropFormat(_ preset: VideoCropFormatPreset) {
        cancelPendingToolReset(for: .presets)

        let previousSelectedTool = presentationState.selectedTool
        let previousCropState = cropEditingState

        guard let referenceSize = currentCropReferenceSize() else { return }

        let nextCropState = EditorCropEditingCoordinator.selectingCropFormat(
            preset,
            from: previousCropState,
            referenceSize: referenceSize
        )

        guard let nextCropState else { return }

        applyCropEditingState(nextCropState)
        presentationState.selectedTool = nil
        syncCropToolState()

        let status = previousSelectedTool != presentationState.selectedTool || previousCropState != nextCropState

        guard status else { return }

        markEditingConfigurationChanged()
    }

    func selectSocialVideoDestination(
        _ destination: VideoEditingConfiguration.SocialVideoDestination
    ) {
        cancelPendingToolReset(for: .presets)
        let previousCropState = cropEditingState

        guard let referenceSize = currentCropReferenceSize() else { return }

        let nextCropState = EditorCropEditingCoordinator.selectingSocialVideoDestination(
            destination,
            from: previousCropState,
            referenceSize: referenceSize
        )

        guard let nextCropState else { return }

        applyCropEditingState(nextCropState)
        syncCropToolState()

        guard previousCropState != nextCropState else { return }

        markEditingConfigurationChanged()
    }

    func setAudio(_ audio: Audio) {
        cancelPendingToolReset(for: .audio)
        guard var currentVideo else { return }

        presentationState.selectedAudioTrack = EditorAudioEditingCoordinator.setRecordedAudio(
            audio,
            in: &currentVideo
        )
        self.currentVideo = currentVideo
        markEditingConfigurationChanged()
    }

    func removeAudio() {
        guard let url = currentVideo?.audio?.url else { return }
        guard var currentVideo else { return }
        cancelPendingToolReset(for: .audio)
        FileManager.default.removeIfExists(for: url)
        presentationState.selectedAudioTrack = EditorAudioEditingCoordinator.removeRecordedAudio(
            from: &currentVideo,
            selectedTool: presentationState.selectedTool
        )
        self.currentVideo = currentVideo
        markEditingConfigurationChanged()
    }

    func reset(
        _ tool: ToolEnum,
        videoPlayer: VideoPlayerManager
    ) {
        switch tool {
        case .cut:
            resetToolCut()
        case .speed:
            resetToolSpeed(videoPlayer: videoPlayer)
        case .presets:
            resetToolPresets()
        case .audio:
            resetToolAudio(videoPlayer: videoPlayer)
        case .adjusts:
            resetToolAdjusts(videoPlayer: videoPlayer)
        case .transcript:
            resetTranscript()
        }

        markEditingConfigurationChanged()

        schedulePendingToolReset(for: tool)
    }

    func selectTool(_ tool: ToolEnum) {
        guard
            let selectedTool = EditorToolSelectionCoordinator.selectTool(
                tool,
                enabledTools: enabledTools
            )
        else { return }

        presentationState.selectedTool = selectedTool
        markEditingConfigurationChanged()
    }

    func closeSelectedTool() {
        presentationState.selectedTool = EditorToolSelectionCoordinator.closeSelectedTool()
        markEditingConfigurationChanged()
    }

    func handleCurrentVideoChange(
        _ video: Video?,
        videoPlayer: VideoPlayerManager
    ) {
        guard let video else { return }
        frames = EditorAppearanceEditingCoordinator.framesState(from: video)
        videoPlayer.syncPlaybackState(with: video)
        videoPlayer.setColorAdjusts(video.colorAdjusts)
    }

    func resolvedPlayerDisplaySize(for video: Video, in containerSize: CGSize) -> CGSize {
        VideoEditorLayoutResolver.resolvedPlayerDisplaySize(
            for: video,
            in: containerSize
        )
    }

    func resolvedCropPreviewCanvas(
        for video: Video,
        in containerSize: CGSize
    ) -> VideoEditorCropPreviewCanvas {
        VideoEditorLayoutResolver.resolvedCropPreviewCanvas(
            for: video,
            freeformRect: cropPresentationState.freeformRect,
            in: containerSize,
            fallbackContainerSize: lastPlayerContainerSize
        )
    }

    func updateCurrentVideoLayout(
        to size: CGSize
    ) {
        guard var currentVideo else { return }

        let didChangeFrameSize = currentVideo.frameSize != size
        let didChangeGeometrySize = currentVideo.geometrySize != size

        guard didChangeFrameSize || didChangeGeometrySize else { return }

        currentVideo.frameSize = size
        currentVideo.geometrySize = size

        self.currentVideo = currentVideo
    }

    func handleRateChange(_ rate: Float, videoPlayer: VideoPlayerManager) {
        let previousRate = currentVideo?.rate ?? 1
        videoPlayer.pause()
        updateRate(rate: rate)
        if let currentVideo {
            videoPlayer.syncPlaybackState(with: currentVideo, previousRate: previousRate)
        }
    }

    func removeAudio(using videoPlayer: VideoPlayerManager) {
        videoPlayer.pause()
        removeAudio()
    }

    func selectAudioTrack(_ track: VideoEditingConfiguration.SelectedTrack) {
        let previousTrack = presentationState.selectedAudioTrack
        presentationState.selectedAudioTrack = EditorAudioEditingCoordinator.selectedTrack(
            track,
            hasRecordedAudioTrack: hasRecordedAudioTrack
        )

        if previousTrack != presentationState.selectedAudioTrack {
            markEditingConfigurationChanged()
        }
    }

    var hasRecordedAudioTrack: Bool {
        currentVideo?.audio != nil
    }

    func updateSelectedTrackVolume(_ value: Float, videoPlayer: VideoPlayerManager) {
        cancelPendingToolReset(for: .audio)
        guard var currentVideo else { return }

        EditorAudioEditingCoordinator.updateSelectedTrackVolume(
            value,
            in: &currentVideo,
            selectedTrack: presentationState.selectedAudioTrack
        )
        self.currentVideo = currentVideo

        videoPlayer.setVolume(presentationState.selectedAudioTrack == .video, value: value)
        markEditingConfigurationChanged()
    }

    func selectedTrackVolume() -> Float {
        EditorAudioEditingCoordinator.selectedTrackVolume(
            in: currentVideo,
            selectedTrack: presentationState.selectedAudioTrack
        )
    }

    private func syncFramesState() {
        guard var currentVideo else { return }
        EditorAppearanceEditingCoordinator.syncFrames(
            frames,
            into: &currentVideo
        )
        self.currentVideo = currentVideo
        markEditingConfigurationChanged()
    }

    func setSourceVideoIfNeeded(
        _ sourceVideoURL: URL?,
        editingConfiguration: VideoEditingConfiguration? = nil,
        availableSize: CGSize,
        videoPlayer: VideoPlayerManager
    ) {
        guard
            let bootstrap = EditorSessionCoordinator.beginSourceVideoSession(
                sourceVideoURL: sourceVideoURL,
                editingConfiguration: editingConfiguration,
                availableSize: availableSize,
                hasLoadedSourceVideo: hasLoadedSourceVideo,
                containerSizeResolver: playerContainerSize(in:)
            )
        else {
            lastPlayerContainerSize = playerContainerSize(in: availableSize)
            return
        }

        lastPlayerContainerSize = bootstrap.containerSize
        hasLoadedSourceVideo = true
        prepareEditingConfigurationForInitialLoad(
            bootstrap.editingConfiguration,
            videoPlayer: videoPlayer
        )
        videoPlayer.loadState = .loaded(bootstrap.sourceVideoURL)
        setNewVideo(bootstrap.sourceVideoURL, containerSize: bootstrap.containerSize)
    }

    func handleRecordedVideo(_ url: URL, videoPlayer: VideoPlayerManager) {
        let recordedVideoSession = EditorSessionCoordinator.recordedVideoSession(url)
        hasLoadedSourceVideo = recordedVideoSession.hasLoadedSourceVideo
        presentationState.selectedAudioTrack = recordedVideoSession.selectedAudioTrack
        videoPlayer.loadState = recordedVideoSession.playerLoadState
        setNewVideo(url, containerSize: lastPlayerContainerSize)
    }

    func presentExporter() {
        presentationState.selectedTool = nil
        markEditingConfigurationChanged()
        taskCoordinator.scheduleExporterPresentation(
            after: Constants.exportPresentationDelay
        ) { [weak self] in
            guard let self else { return }
            presentationState.showVideoQualitySheet = true
        }
    }

    func configureTranscription(
        provider: (any VideoTranscriptionProvider)?,
        availableStyles: [TranscriptStyle] = [],
        preferredLocale: String? = nil
    ) {
        transcriptionProvider = provider
        self.availableTranscriptStyles = availableStyles
        preferredTranscriptLocale = preferredLocale

        guard var transcriptDocument else {
            syncTranscriptRuntimeState()
            return
        }

        guard transcriptDocument.availableStyles != availableStyles else {
            syncTranscriptRuntimeState()
            return
        }

        transcriptDocument.availableStyles = availableStyles
        self.transcriptDocument = transcriptDocument
        markEditingConfigurationChanged()
        syncTranscriptRuntimeState()
    }

    func transcribeCurrentVideo() {
        guard let transcriptionProvider else {
            applyTranscriptFailure(.providerNotConfigured)
            return
        }

        guard let currentVideo, currentVideo.url.isFileURL else {
            applyTranscriptFailure(.invalidVideoSource)
            return
        }

        let input = VideoTranscriptionInput(
            assetIdentifier: currentVideo.url.absoluteString,
            source: .fileURL(currentVideo.url),
            preferredLocale: preferredTranscriptLocale
        )

        transcriptState = .loading
        taskCoordinator.replaceTranscriptionTask { [weak self] token in
            guard let self else { return }

            do {
                let result = try await transcriptionProvider.transcribeVideo(input: input)
                guard taskCoordinator.acceptsTranscriptionTask(token) else { return }

                guard !result.segments.isEmpty else {
                    applyTranscriptFailure(.emptyResult)
                    return
                }

                guard let currentVideo = self.currentVideo else {
                    applyTranscriptFailure(.invalidVideoSource)
                    return
                }

                let document = EditorTranscriptMappingCoordinator.makeDocument(
                    from: result,
                    availableStyles: availableTranscriptStyles,
                    trimRange: currentVideo.rangeDuration,
                    playbackRate: currentVideo.rate
                )
                applyTranscriptSuccess(document)
            } catch is CancellationError {
                guard taskCoordinator.acceptsTranscriptionTask(token) else { return }
                applyTranscriptFailure(.cancelled)
            } catch {
                guard taskCoordinator.acceptsTranscriptionTask(token) else { return }
                applyTranscriptFailure(
                    .providerFailure(message: error.localizedDescription)
                )
            }
        }
    }

    func cancelDeferredTasks() {
        taskCoordinator.cancelDeferredTasks()
    }

    func currentEditingConfiguration(currentTimelineTime: Double? = nil) -> VideoEditingConfiguration? {
        EditorSessionCoordinator.currentEditingConfiguration(
            from: currentVideo,
            frames: frames,
            freeformRect: cropPresentationState.freeformRect,
            canvasSnapshot: cropPresentationState.canvasEditorState.snapshot(),
            selectedAudioTrack: presentationState.selectedAudioTrack,
            transcriptFeatureState: transcriptFeatureState,
            transcriptDocument: transcriptDocument,
            selectedTool: presentationState.selectedTool,
            socialVideoDestination: cropPresentationState.socialVideoDestination,
            showsSafeAreaGuides: false,
            currentTimelineTime: currentTimelineTime
        )
    }

    func videoCanvasSource(for video: Video) -> VideoCanvasSourceDescriptor {
        VideoCanvasSourceDescriptor(
            naturalSize: resolvedCropReferenceSize(for: video),
            preferredTransform: .identity,
            userRotationDegrees: video.rotation,
            isMirrored: video.isMirror
        )
    }

    func handleCanvasPreviewChange() {
        cancelPendingToolReset(for: .presets)
        syncCropToolState()
        markEditingConfigurationChanged()
    }

    func resetCanvasTransform() {
        cropPresentationState.canvasEditorState.resetTransform()
        handleCanvasPreviewChange()
    }

    func activeTranscriptSegment(
        at timelineTime: Double
    ) -> EditableTranscriptSegment? {
        transcriptDocument?.segments.first {
            guard let timelineRange = $0.timeMapping.timelineRange else { return false }
            return timelineRange.contains(timelineTime)
        }
    }

    func transcriptStyle(
        for segment: EditableTranscriptSegment
    ) -> TranscriptStyle? {
        guard let styleID = segment.styleID else { return nil }
        return transcriptDocument?.availableStyles.first(where: { $0.id == styleID })
    }

    func setTranscriptOverlaySelection(_ isSelected: Bool) {
        presentationState.isTranscriptOverlaySelected = isSelected
    }

    func updateTranscriptOverlayPosition(
        _ position: TranscriptOverlayPosition
    ) {
        guard var transcriptDocument else { return }
        guard transcriptDocument.overlayPosition != position else { return }

        transcriptDocument.overlayPosition = position
        self.transcriptDocument = transcriptDocument
        markEditingConfigurationChanged()
    }

    func updateTranscriptOverlaySize(
        _ size: TranscriptOverlaySize
    ) {
        guard var transcriptDocument else { return }
        guard transcriptDocument.overlaySize != size else { return }

        transcriptDocument.overlaySize = size
        self.transcriptDocument = transcriptDocument
        markEditingConfigurationChanged()
    }

    func playerContainerSize(in availableSize: CGSize) -> CGSize {
        VideoEditorLayoutResolver.playerContainerSize(
            in: availableSize
        )
    }

    func prepareEditingConfigurationForInitialLoad(
        _ editingConfiguration: VideoEditingConfiguration?,
        videoPlayer: VideoPlayerManager
    ) {
        let preparedState = EditorInitialLoadCoordinator.prepare(
            editingConfiguration
        )

        pendingEditingConfiguration = preparedState.pendingEditingConfiguration
        presentationState.selectedTool = preparedState.selectedTool
        presentationState.selectedAudioTrack = preparedState.selectedAudioTrack
        cropPresentationState.apply(preparedState.cropEditingState)
        transcriptFeatureState = preparedState.transcriptFeatureState
        transcriptDocument = preparedState.transcriptDocument
        syncTranscriptRuntimeState()

        if let currentTimelineTime = preparedState.initialTimelineTime {
            videoPlayer.currentTime = currentTimelineTime
        }
    }

    func setTranscriptDocument(
        _ document: TranscriptDocument?,
        featureState: TranscriptFeaturePersistenceState = .loaded
    ) {
        transcriptFeatureState = document == nil ? .idle : featureState
        transcriptDocument = document
        remapTranscriptDocumentIfNeeded()
        syncTranscriptRuntimeState()
        markEditingConfigurationChanged()
    }

    func updateTranscriptSegmentText(
        _ text: String,
        segmentID: UUID
    ) {
        guard var transcriptDocument else { return }
        guard let segmentIndex = transcriptDocument.segments.firstIndex(where: { $0.id == segmentID }) else {
            return
        }

        guard transcriptDocument.segments[segmentIndex].editedText != text else { return }

        transcriptDocument.segments[segmentIndex].editedText = text
        self.transcriptDocument = transcriptDocument
        markEditingConfigurationChanged()
    }

    func updateTranscriptSegmentStyle(
        _ styleID: TranscriptStyle.StyleIdentifier?,
        segmentID: UUID
    ) {
        guard var transcriptDocument else { return }
        guard let segmentIndex = transcriptDocument.segments.firstIndex(where: { $0.id == segmentID }) else {
            return
        }

        guard transcriptDocument.segments[segmentIndex].styleID != styleID else { return }

        transcriptDocument.segments[segmentIndex].styleID = styleID
        self.transcriptDocument = transcriptDocument
        markEditingConfigurationChanged()
    }

    func resetTranscript() {
        taskCoordinator.cancelTranscriptionTask()
        transcriptFeatureState = .idle
        transcriptState = .idle
        transcriptDocument = nil
        presentationState.isTranscriptOverlaySelected = false
        markEditingConfigurationChanged()
    }

    func applyPendingEditingConfiguration(
        to video: inout Video,
        containerSize: CGSize = .zero
    ) {
        EditorInitialLoadCoordinator.applyPendingEditingConfiguration(
            pendingEditingConfiguration,
            to: &video,
            containerSize: containerSize
        ) { [self] video, containerSize in
            resolvedPlayerDisplaySize(
                for: video,
                in: containerSize
            )
        }
    }

    func restorePendingEditingPresentationState() async {
        guard
            let restoredState = await EditorInitialLoadCoordinator.restorePendingEditingPresentationState(
                from: pendingEditingConfiguration,
                referenceSize: currentCropReferenceSize() ?? .zero,
                hasRecordedAudioTrack: currentVideo?.audio != nil,
                enabledTools: enabledTools
            )
        else {
            return
        }

        applyCropEditingState(restoredState.cropEditingState)
        presentationState.selectedAudioTrack = restoredState.selectedAudioTrack
        presentationState.selectedTool = restoredState.selectedTool
        remapTranscriptDocumentIfNeeded()
        syncTranscriptRuntimeState()

        pendingEditingConfiguration = nil
    }

    // MARK: - Private Methods

    private func syncCropToolState() {
        guard let currentVideo else { return }

        if EditorCropEditingCoordinator.shouldApplyPresetTool(
            for: currentVideo,
            state: cropEditingState
        ) {
            self.currentVideo?.appliedTool(for: .presets)
        } else {
            self.currentVideo?.removeTool(for: .presets)
        }
    }

    private func currentCropReferenceSize() -> CGSize? {
        guard let currentVideo else { return nil }
        return VideoEditorLayoutResolver.resolvedCropReferenceSize(
            for: currentVideo,
            fallbackContainerSize: lastPlayerContainerSize
        )
    }

    private func resolvedCropReferenceSize(for video: Video) -> CGSize {
        VideoEditorLayoutResolver.resolvedCropReferenceSize(
            for: video,
            fallbackContainerSize: lastPlayerContainerSize
        )
    }

    private func resetToolCut() {
        guard var currentVideo else { return }

        EditorPlaybackEditingCoordinator.restoreDefaultCut(
            in: &currentVideo
        )
        self.currentVideo = currentVideo
        remapTranscriptDocumentIfNeeded()
    }

    private func resetToolSpeed(videoPlayer: VideoPlayerManager) {
        let previousRate = currentVideo?.rate ?? 1
        videoPlayer.pause()
        guard var currentVideo else { return }

        EditorPlaybackEditingCoordinator.restoreDefaultRate(
            in: &currentVideo
        )
        self.currentVideo = currentVideo
        remapTranscriptDocumentIfNeeded()
        videoPlayer.syncPlaybackState(with: currentVideo, previousRate: previousRate)
    }

    private func resetToolPresets() {
        currentVideo?.rotation = 0
        currentVideo?.isMirror = false
        applyCropEditingState(.initial)
    }

    private func resetToolAudio(videoPlayer: VideoPlayerManager) {
        presentationState.selectedAudioTrack = .video

        if currentVideo?.audio != nil {
            removeAudio(using: videoPlayer)
            return
        }

        currentVideo?.setVolume(1.0)
        videoPlayer.setVolume(true, value: 1.0)
    }

    private func resetToolAdjusts(videoPlayer: VideoPlayerManager) {
        guard var currentVideo else { return }
        guard
            EditorAppearanceEditingCoordinator.restoreDefaultAdjusts(
                in: &currentVideo
            )
        else { return }

        self.currentVideo = currentVideo
        videoPlayer.clearColorAdjusts()
    }

    private var cropEditingState: EditorCropEditingState {
        cropPresentationState.editingState
    }

    private func applyCropEditingState(_ state: EditorCropEditingState) {
        cropPresentationState.apply(state)
    }

    private func remapTranscriptDocumentIfNeeded() {
        guard let currentVideo else { return }

        transcriptDocument = EditorTranscriptRemappingCoordinator.remap(
            transcriptDocument,
            trimRange: currentVideo.rangeDuration,
            playbackRate: currentVideo.rate
        )
    }

    private func applyTranscriptSuccess(_ document: TranscriptDocument) {
        transcriptFeatureState = .loaded
        transcriptDocument = document
        transcriptState = .loaded
        markEditingConfigurationChanged()
    }

    private func applyTranscriptFailure(_ error: TranscriptError) {
        transcriptState = .failed(error)

        guard transcriptDocument == nil else { return }

        transcriptFeatureState = .failed
        markEditingConfigurationChanged()
    }

    private func syncTranscriptRuntimeState() {
        switch transcriptFeatureState {
        case .idle:
            transcriptState = .idle
        case .loaded:
            transcriptState = transcriptDocument == nil ? .idle : .loaded
        case .failed:
            transcriptState = .failed(
                .providerFailure(message: "The previous transcription request failed.")
            )
        }
    }

    private func markEditingConfigurationChanged() {
        presentationState.markEditingConfigurationChanged()
    }

}
