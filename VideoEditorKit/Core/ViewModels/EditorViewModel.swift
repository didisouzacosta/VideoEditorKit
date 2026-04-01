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

    var currentVideo: Video?
    var frames = VideoFrames()
    let presentationState = EditorPresentationState()
    let cropPresentationState = EditorCropPresentationState()

    var hasCurrentVideo: Bool {
        currentVideo != nil
    }

    var exportVideo: Video? {
        presentationState.showVideoQualitySheet ? currentVideo : nil
    }

    var isMirrorEnabled: Bool {
        currentVideo?.isMirror ?? false
    }

    var cropRotation: Double {
        get { currentVideo?.rotation ?? 0 }
        set { setRotation(newValue) }
    }

    var shouldShowCropOverlay: Bool {
        cropPresentationState.shouldShowCropOverlay
    }

    var isCropOverlayInteractive: Bool {
        selectedCropPreset() != .original
    }

    var shouldUseCropPresetSpotlight: Bool {
        selectedCropPreset() != .original
    }

    var shouldShowSafeAreaOverlay: Bool {
        EditorCropEditingCoordinator.shouldShowSafeAreaOverlay(
            for: cropEditingState
        )
    }

    var activeSafeAreaGuideProfile: SafeAreaGuideProfile? {
        guard shouldShowSafeAreaOverlay else { return nil }
        return EditorCropEditingCoordinator.activeSafeAreaGuideProfile(
            for: cropEditingState
        )
    }

    // MARK: - Private Properties

    private let dependencies: Dependencies
    private let taskCoordinator: EditorTaskCoordinator

    private var enabledTools = Set(ToolEnum.all)
    private var hasLoadedSourceVideo = false
    private var lastPlayerContainerSize = CGSize(width: 1, height: 220)
    private var lastThumbnailDisplayScale: CGFloat = 1
    private var pendingEditingConfiguration: VideoEditingConfiguration?

    // MARK: - Initializer

    init(_ dependencies: Dependencies = .live) {
        self.dependencies = dependencies
        taskCoordinator = EditorTaskCoordinator(dependencies.sleep)
    }

    // MARK: - Public Methods

    func setNewVideo(_ url: URL, containerSize: CGSize) {
        invalidateThumbnailRequests()
        cancelPendingToolResetTasks()
        currentVideo = nil
        lastPlayerContainerSize = containerSize

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

    private func resolvedSourceSizeForBadge() -> CGSize {
        if let presentationSize = currentVideo?.presentationSize,
            presentationSize.width > 0,
            presentationSize.height > 0
        {
            return presentationSize
        }

        if let geometrySize = currentVideo?.geometrySize,
            geometrySize.width > 0,
            geometrySize.height > 0
        {
            return geometrySize
        }

        return .zero
    }

    func setFrameColor(_ color: Color) {
        frames.frameColor = color
        syncFramesState()
    }

    func setFrameScale(_ scaleValue: Double) {
        frames.scaleValue = scaleValue
        syncFramesState()
    }

    func setCorrections(_ correction: ColorCorrection) {
        guard var currentVideo else { return }
        cancelPendingToolReset(for: .corrections)

        currentVideo.colorCorrection = correction
        if correction.isIdentity {
            currentVideo.removeTool(for: .corrections)
        } else {
            currentVideo.appliedTool(for: .corrections)
        }

        self.currentVideo = currentVideo
        markEditingConfigurationChanged()
    }

    func updateRate(rate: Float) {
        cancelPendingToolReset(for: .speed)
        currentVideo?.updateRate(rate)
        applySelectedToolIfNeeded()
        markEditingConfigurationChanged()
    }

    func setCut() {
        guard let video = currentVideo else { return }
        cancelPendingToolReset(for: .cut)

        let isTrimmed =
            video.rangeDuration.lowerBound > 0
            || abs(video.rangeDuration.upperBound - video.originalDuration) > Constants.numericTolerance

        if isTrimmed {
            currentVideo?.appliedTool(for: .cut)
        } else {
            currentVideo?.removeTool(for: .cut)
        }

        markEditingConfigurationChanged()
    }

    func resetCut() {
        cancelPendingToolReset(for: .cut)
        currentVideo?.resetRangeDuration()
        currentVideo?.removeTool(for: .cut)
        markEditingConfigurationChanged()
    }

    func rotate() {
        cancelPendingToolReset(for: .presets)
        currentVideo?.rotate()
        applySelectedToolIfNeeded()
        markEditingConfigurationChanged()
    }

    func setRotation(_ rotation: Double) {
        guard currentVideo?.rotation != rotation else { return }
        cancelPendingToolReset(for: .presets)
        currentVideo?.rotation = rotation
        applySelectedToolIfNeeded()
        markEditingConfigurationChanged()
    }

    func toggleMirror() {
        cancelPendingToolReset(for: .presets)
        currentVideo?.isMirror.toggle()
        applySelectedToolIfNeeded()
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
        guard
            let nextCropState = EditorCropEditingCoordinator.selectingCropFormat(
                preset,
                from: previousCropState,
                referenceSize: referenceSize
            )
        else { return }

        applyCropEditingState(nextCropState)
        presentationState.selectedTool = nil
        syncCropToolState()

        guard
            previousSelectedTool != presentationState.selectedTool
                || previousCropState != nextCropState
        else { return }

        markEditingConfigurationChanged()
    }

    func selectSocialVideoDestination(
        _ destination: VideoEditingConfiguration.SocialVideoDestination
    ) {
        cancelPendingToolReset(for: .presets)
        let previousCropState = cropEditingState

        guard let referenceSize = currentCropReferenceSize() else { return }
        guard
            let nextCropState = EditorCropEditingCoordinator.selectingSocialVideoDestination(
                destination,
                from: previousCropState,
                referenceSize: referenceSize
            )
        else { return }

        applyCropEditingState(nextCropState)
        syncCropToolState()

        guard previousCropState != nextCropState else { return }

        markEditingConfigurationChanged()
    }

    func toggleSafeAreaOverlay() {
        cancelPendingToolReset(for: .presets)
        let previousCropState = cropEditingState
        guard
            let nextCropState = EditorCropEditingCoordinator.togglingSafeAreaOverlay(
                from: previousCropState
            )
        else { return }

        applyCropEditingState(nextCropState)
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

    func applySelectedToolIfNeeded() {
        guard let selectedTool = presentationState.selectedTool else { return }
        currentVideo?.appliedTool(for: selectedTool)
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
            currentVideo?.resetRangeDuration()
        case .speed:
            let previousRate = currentVideo?.rate ?? 1
            videoPlayer.pause()
            currentVideo?.resetRate()
            if let currentVideo {
                videoPlayer.syncPlaybackState(with: currentVideo, previousRate: previousRate)
            }
        case .presets:
            currentVideo?.rotation = 0
            currentVideo?.isMirror = false
            applyCropEditingState(.initial)
        case .audio:
            presentationState.selectedAudioTrack = .video
            if currentVideo?.audio != nil {
                removeAudio(using: videoPlayer)
                return
            }

            currentVideo?.setVolume(1.0)
            videoPlayer.setVolume(true, value: 1.0)
        case .corrections:
            currentVideo?.colorCorrection = .init()
            videoPlayer.clearColorCorrection()
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
        frames = video.videoFrames ?? VideoFrames()
        videoPlayer.syncPlaybackState(with: video)
        videoPlayer.setColorCorrection(video.colorCorrection)
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

    func isCropFormatSelected(_ preset: VideoCropFormatPreset) -> Bool {
        selectedCropPreset() == preset
    }

    func selectedCropPreset() -> VideoCropFormatPreset {
        EditorCropEditingCoordinator.selectedCropPreset(
            from: cropEditingState,
            referenceSize: currentCropReferenceSize()
        )
    }

    func shouldShowCropPresetBadge() -> Bool {
        selectedCropPreset() != .original
    }

    func selectedCropPresetBadgeTitle() -> String {
        if selectedCropPreset() == .vertical9x16 {
            return "Social"
        }

        return selectedCropPreset().title
    }

    func selectedCropPresetBadgeDimension() -> String {
        let preset = selectedCropPreset()

        switch preset {
        case .original:
            let sourceSize = resolvedSourceSizeForBadge()
            guard sourceSize.width > 0, sourceSize.height > 0 else { return preset.dimensionTitle }
            return "\(Int(sourceSize.width.rounded()))x\(Int(sourceSize.height.rounded()))"
        case .vertical9x16,
            .square1x1,
            .portrait4x5,
            .landscape16x9:
            return preset.dimensionTitle
        }
    }

    func isSocialVideoDestinationSelected(
        _ destination: VideoEditingConfiguration.SocialVideoDestination
    ) -> Bool {
        cropPresentationState.socialVideoDestination == destination
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
        currentVideo?.videoFrames = frames
        markEditingConfigurationChanged()
    }

    func setSourceVideoIfNeeded(
        _ sourceVideoURL: URL?,
        editingConfiguration: VideoEditingConfiguration? = nil,
        availableSize: CGSize,
        videoPlayer: VideoPlayerManager
    ) {
        let containerSize = playerContainerSize(in: availableSize)
        lastPlayerContainerSize = containerSize

        guard !hasLoadedSourceVideo, let sourceVideoURL else { return }
        hasLoadedSourceVideo = true
        prepareEditingConfigurationForInitialLoad(
            editingConfiguration,
            videoPlayer: videoPlayer
        )
        videoPlayer.loadState = .loaded(sourceVideoURL)
        setNewVideo(sourceVideoURL, containerSize: containerSize)
    }

    func handleRecordedVideo(_ url: URL, videoPlayer: VideoPlayerManager) {
        hasLoadedSourceVideo = true
        presentationState.selectedAudioTrack = .video
        videoPlayer.loadState = .loaded(url)
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

    func cancelDeferredTasks() {
        taskCoordinator.cancelDeferredTasks()
    }

    func currentEditingConfiguration(currentTimelineTime: Double? = nil) -> VideoEditingConfiguration? {
        guard var currentVideo else { return nil }

        currentVideo.videoFrames = frames.isActive ? frames : nil

        return VideoEditingConfigurationMapper.makeConfiguration(
            from: currentVideo,
            freeformRect: cropPresentationState.freeformRect,
            canvasSnapshot: cropPresentationState.canvasEditorState.snapshot(),
            selectedAudioTrack: presentationState.selectedAudioTrack,
            selectedTool: presentationState.selectedTool,
            socialVideoDestination: cropPresentationState.socialVideoDestination,
            showsSafeAreaGuides: cropPresentationState.showsSafeAreaOverlay,
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

        if let currentTimelineTime = preparedState.initialTimelineTime {
            videoPlayer.currentTime = currentTimelineTime
        }
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

    private var cropEditingState: EditorCropEditingState {
        cropPresentationState.editingState
    }

    private func applyCropEditingState(_ state: EditorCropEditingState) {
        cropPresentationState.apply(state)
    }

    private func markEditingConfigurationChanged() {
        presentationState.markEditingConfigurationChanged()
    }

}
