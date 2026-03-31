//
//  EditorViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class EditorViewModel {

    // MARK: - Public Properties

    var currentVideo: Video?
    private(set) var selectedTools: ToolEnum?
    var frames = VideoFrames()
    var selectedAudioTrack: AudioTrackSelection = .video
    var showVideoQualitySheet = false
    var showRecordView = false
    var cropFreeformRect: VideoEditingConfiguration.FreeformRect?
    var socialVideoDestination: VideoEditingConfiguration.SocialVideoDestination?
    var showsSafeAreaOverlay = false
    var canvasEditorState = VideoCanvasEditorState()
    private(set) var editingConfigurationChangeCounter = 0

    var hasCurrentVideo: Bool {
        currentVideo != nil
    }

    var exportVideo: Video? {
        showVideoQualitySheet ? currentVideo : nil
    }

    var isMirrorEnabled: Bool {
        currentVideo?.isMirror ?? false
    }

    var cropRotation: Double {
        get { currentVideo?.rotation ?? 0 }
        set { setRotation(newValue) }
    }

    var shouldShowCropOverlay: Bool {
        cropFreeformRect != nil || canvasEditorState.snapshot().isIdentity == false
    }

    var isCropOverlayInteractive: Bool {
        selectedCropPreset() != .original
    }

    var shouldUseCropPresetSpotlight: Bool {
        selectedCropPreset() != .original
    }

    var shouldShowSafeAreaOverlay: Bool {
        showsSafeAreaOverlay
            && resolvedSafeAreaGuideProfile() != nil
    }

    var activeSafeAreaGuideProfile: SafeAreaGuideProfile? {
        guard showsSafeAreaOverlay else { return nil }
        return resolvedSafeAreaGuideProfile()
    }

    // MARK: - Private Properties

    @ObservationIgnored private var loadVideoTask: Task<Void, Never>?
    @ObservationIgnored private var thumbnailsTask: Task<Void, Never>?
    @ObservationIgnored private var exportSheetTask: Task<Void, Never>?

    private var enabledTools = Set(ToolEnum.all)
    private var hasLoadedSourceVideo = false
    private var lastPlayerContainerSize = CGSize(width: 1, height: 220)
    private var lastThumbnailDisplayScale: CGFloat = 1
    private var pendingEditingConfiguration: VideoEditingConfiguration?

    // MARK: - Public Methods

    func setNewVideo(_ url: URL, containerSize: CGSize) {
        loadVideoTask?.cancel()
        thumbnailsTask?.cancel()
        currentVideo = nil
        lastPlayerContainerSize = containerSize

        loadVideoTask = Task { [weak self] in
            var video = await Video.load(from: url)
            guard !Task.isCancelled else { return }

            self?.applyPendingEditingConfiguration(
                to: &video,
                containerSize: containerSize
            )
            self?.frames = video.videoFrames ?? VideoFrames()
            self?.currentVideo = video
            await self?.restorePendingEditingPresentationState()
            self?.loadThumbnails(
                for: video,
                containerSize: containerSize,
                displayScale: self?.lastThumbnailDisplayScale ?? 1
            )
            self?.markEditingConfigurationChanged()
        }
    }

    func setToolAvailability(_ tools: [ToolAvailability]) {
        enabledTools = Set(tools.filter(\.isEnabled).map(\.tool))

        let previousSelection = selectedTools

        if let selectedTools, !canSelectTool(selectedTools) {
            self.selectedTools = nil
        }

        if previousSelection != selectedTools {
            markEditingConfigurationChanged()
        }
    }

    deinit {
        loadVideoTask?.cancel()
        thumbnailsTask?.cancel()
        exportSheetTask?.cancel()
    }

}

extension EditorViewModel {

    enum AudioTrackSelection: String, CaseIterable, Identifiable {
        case video
        case recorded

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .video:
                "Video"
            case .recorded:
                "Recorded"
            }
        }
    }

    // MARK: - Public Methods

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
        let hasLowResolutionThumbnails = (video.thumbnailsImages.first?.image?.size.width ?? 0) < expectedThumbnailWidth

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
        let videoID = video.id

        thumbnailsTask = Task.detached(priority: .userInitiated) {
            let thumbnails = await video.makeThumbnails(
                containerSize: containerSize,
                displayScale: displayScale
            )

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self, self.currentVideo?.id == videoID else { return }
                self.currentVideo?.thumbnailsImages = thumbnails
            }
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

}

extension EditorViewModel {

    struct CropPreviewCanvas: Equatable {

        // MARK: - Public Properties

        let referenceSize: CGSize
        let contentSize: CGSize
        let viewportSize: CGSize

    }

    // MARK: - Public Methods

    func setFrames() {
        currentVideo?.videoFrames = frames
        setTools()
        markEditingConfigurationChanged()
    }

    func setCorrections(_ correction: ColorCorrection) {
        guard var currentVideo else { return }

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
        currentVideo?.updateRate(rate)
        setTools()
        markEditingConfigurationChanged()
    }

    func setCut() {
        guard let video = currentVideo else { return }

        let isTrimmed =
            video.rangeDuration.lowerBound > 0
            || abs(video.rangeDuration.upperBound - video.originalDuration) > 0.001

        if isTrimmed {
            currentVideo?.appliedTool(for: .cut)
        } else {
            currentVideo?.removeTool(for: .cut)
        }

        markEditingConfigurationChanged()
    }

    func resetCut() {
        currentVideo?.resetRangeDuration()
        currentVideo?.removeTool(for: .cut)
        markEditingConfigurationChanged()
    }

    func rotate() {
        currentVideo?.rotate()
        setTools()
        markEditingConfigurationChanged()
    }

    func setRotation(_ rotation: Double) {
        guard currentVideo?.rotation != rotation else { return }
        currentVideo?.rotation = rotation
        setTools()
        markEditingConfigurationChanged()
    }

    func toggleMirror() {
        currentVideo?.isMirror.toggle()
        setTools()
        markEditingConfigurationChanged()
    }

    func setCropFreeformRect(_ rect: VideoEditingConfiguration.FreeformRect?) {
        guard cropFreeformRect != rect else { return }
        cropFreeformRect = rect
        syncCropToolState()
        markEditingConfigurationChanged()
    }

    func selectCropFormat(_ preset: VideoCropFormatPreset) {
        let previousSelectedTool = selectedTools
        let previousCropRect = cropFreeformRect
        let previousSocialVideoDestination = socialVideoDestination
        let previousShowsSafeAreaOverlay = showsSafeAreaOverlay
        let previousCanvasSnapshot = canvasEditorState.snapshot()
        let nextCropRect: VideoEditingConfiguration.FreeformRect?

        switch preset {
        case .original:
            nextCropRect = nil
            socialVideoDestination = nil
            showsSafeAreaOverlay = false
            canvasEditorState.restore(.initial)
        case .vertical9x16,
            .square1x1,
            .portrait4x5,
            .landscape16x9:
            guard let referenceSize = currentCropReferenceSize() else { return }
            nextCropRect = preset.makeFreeformRect(for: referenceSize)

            if preset.isSocialVideoPreset {
                let hadSafeAreaGuide = resolvedSafeAreaGuideProfile() != nil
                socialVideoDestination = nil
                if !hadSafeAreaGuide {
                    showsSafeAreaOverlay = true
                }
                canvasEditorState.preset = .story
            } else {
                socialVideoDestination = nil
                showsSafeAreaOverlay = false
                canvasEditorState.preset = canvasPreset(for: preset)
            }

            canvasEditorState.resetTransform()
            canvasEditorState.showsSafeAreaOverlay = shouldRenderSafeAreaOverlay(
                for: canvasEditorState.preset
            )
        }

        cropFreeformRect = nextCropRect
        selectedTools = nil
        syncCropToolState()

        guard
            previousSelectedTool != selectedTools
                || previousCropRect != cropFreeformRect
                || previousSocialVideoDestination != socialVideoDestination
                || previousShowsSafeAreaOverlay != showsSafeAreaOverlay
                || previousCanvasSnapshot != canvasEditorState.snapshot()
        else { return }

        markEditingConfigurationChanged()
    }

    func selectSocialVideoDestination(
        _ destination: VideoEditingConfiguration.SocialVideoDestination
    ) {
        let previousCropRect = cropFreeformRect
        let previousSocialVideoDestination = socialVideoDestination
        let previousShowsSafeAreaOverlay = showsSafeAreaOverlay
        let previousCanvasSnapshot = canvasEditorState.snapshot()

        guard let referenceSize = currentCropReferenceSize() else { return }

        let hadSocialDestination = socialVideoDestination != nil
        socialVideoDestination = destination
        cropFreeformRect = VideoCropFormatPreset.vertical9x16.makeFreeformRect(
            for: referenceSize
        )
        if !hadSocialDestination {
            showsSafeAreaOverlay = true
        }
        canvasEditorState.preset = .social(platform: destination.socialPlatform)
        canvasEditorState.showsSafeAreaOverlay = shouldRenderSafeAreaOverlay(
            for: canvasEditorState.preset
        )
        syncCropToolState()

        guard
            previousCropRect != cropFreeformRect
                || previousSocialVideoDestination != socialVideoDestination
                || previousShowsSafeAreaOverlay != showsSafeAreaOverlay
                || previousCanvasSnapshot != canvasEditorState.snapshot()
        else { return }

        markEditingConfigurationChanged()
    }

    func toggleSafeAreaOverlay() {
        guard resolvedSafeAreaGuideProfile() != nil else { return }
        showsSafeAreaOverlay.toggle()
        canvasEditorState.showsSafeAreaOverlay = shouldRenderSafeAreaOverlay(
            for: canvasEditorState.preset
        )
        markEditingConfigurationChanged()
    }

    func setAudio(_ audio: Audio) {
        currentVideo?.audio = audio
        selectedAudioTrack = .recorded
        setTools()
        markEditingConfigurationChanged()
    }

    func setTools() {
        guard let selectedTools else { return }
        currentVideo?.appliedTool(for: selectedTools)
    }

    func removeTool() {
        guard let selectedTools else { return }
        currentVideo?.removeTool(for: selectedTools)
    }

    func removeAudio() {
        guard let url = currentVideo?.audio?.url else { return }
        FileManager.default.removeIfExists(for: url)
        currentVideo?.audio = nil
        selectedAudioTrack = .video
        removeTool()
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
            cropFreeformRect = nil
            socialVideoDestination = nil
            showsSafeAreaOverlay = false
            canvasEditorState.restore(.initial)
        case .audio:
            selectedAudioTrack = .video
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

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            self?.currentVideo?.removeTool(for: tool)
            self?.markEditingConfigurationChanged()
        }
    }

    func selectTool(_ tool: ToolEnum) {
        guard canSelectTool(tool) else { return }
        selectedTools = tool
        markEditingConfigurationChanged()
    }

    func closeSelectedTool() {
        selectedTools = nil
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
        let fallbackSize = CGSize(
            width: max(containerSize.width, 1),
            height: max(containerSize.height, 1)
        )

        let baseSize = rotatedBaseSize(for: video)
        guard baseSize.width > 0, baseSize.height > 0 else { return fallbackSize }

        return fittedSize(baseSize, in: fallbackSize)
    }

    func resolvedCropPreviewCanvas(
        for video: Video,
        in containerSize: CGSize
    ) -> CropPreviewCanvas {
        let fallbackSize = CGSize(
            width: max(containerSize.width, 1),
            height: max(containerSize.height, 1)
        )
        let referenceSize = resolvedCropReferenceSize(for: video)
        let contentSize = fittedSize(referenceSize, in: fallbackSize)

        guard
            let aspectRatio = activeCropViewportAspectRatio(
                in: referenceSize
            )
        else {
            return .init(
                referenceSize: referenceSize,
                contentSize: contentSize,
                viewportSize: contentSize
            )
        }

        let viewportSize = fittedAspectSize(
            for: aspectRatio,
            in: containerSize
        )

        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return .init(
                referenceSize: referenceSize,
                contentSize: contentSize,
                viewportSize: contentSize
            )
        }

        return .init(
            referenceSize: referenceSize,
            contentSize: contentSize,
            viewportSize: viewportSize
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
        markEditingConfigurationChanged()
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
        let canvasPreset = selectedCropPresetFromCanvas()

        if canvasPreset != .original {
            return canvasPreset == preset
        }

        guard let referenceSize = currentCropReferenceSize() else {
            return preset == .original && cropFreeformRect == nil
        }

        return preset.matches(cropFreeformRect, in: referenceSize)
    }

    func selectedCropPreset() -> VideoCropFormatPreset {
        let canvasPreset = selectedCropPresetFromCanvas()
        if canvasPreset != .original {
            return canvasPreset
        }

        for preset in VideoCropFormatPreset.editorPresets where preset != .original {
            if isCropFormatSelected(preset) {
                return preset
            }
        }

        return .original
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
        socialVideoDestination == destination
    }

    func removeAudio(using videoPlayer: VideoPlayerManager) {
        videoPlayer.pause()
        removeAudio()
    }

    func selectAudioTrack(_ track: AudioTrackSelection) {
        let previousTrack = selectedAudioTrack

        if track == .recorded, !hasRecordedAudioTrack {
            selectedAudioTrack = .video
            if previousTrack != selectedAudioTrack {
                markEditingConfigurationChanged()
            }
            return
        }

        selectedAudioTrack = track
        if previousTrack != track {
            markEditingConfigurationChanged()
        }
    }

    func audioTrackSelectionBinding() -> Binding<AudioTrackSelection> {
        Binding(
            get: { self.selectedAudioTrack },
            set: { self.selectAudioTrack($0) }
        )
    }

    var hasRecordedAudioTrack: Bool {
        currentVideo?.audio != nil
    }

    func updateSelectedTrackVolume(_ value: Float, videoPlayer: VideoPlayerManager) {
        if selectedAudioTrack == .video {
            currentVideo?.setVolume(value)
        } else {
            currentVideo?.audio?.setVolume(value)
        }

        videoPlayer.setVolume(selectedAudioTrack == .video, value: value)
        syncAudioToolState()
        markEditingConfigurationChanged()
    }

    func selectedTrackVolume() -> Float {
        if selectedAudioTrack == .video {
            return currentVideo?.volume ?? 1.0
        }

        return currentVideo?.audio?.volume ?? 1.0
    }

    func selectedTrackVolumeBinding(videoPlayer: VideoPlayerManager) -> Binding<Float> {
        Binding(
            get: { self.selectedTrackVolume() },
            set: { self.updateSelectedTrackVolume($0, videoPlayer: videoPlayer) }
        )
    }

    private func syncAudioToolState() {
        guard let video = currentVideo else { return }

        let hasRecordedAudio = video.audio != nil
        let hasAdjustedVideoVolume = abs(video.volume - 1.0) > 0.001

        if hasRecordedAudio || hasAdjustedVideoVolume {
            currentVideo?.appliedTool(for: .audio)
        } else {
            currentVideo?.removeTool(for: .audio)
        }
    }

    func frameColorBinding() -> Binding<Color> {
        Binding(
            get: { self.frames.frameColor },
            set: {
                self.frames.frameColor = $0
                self.markEditingConfigurationChanged()
            }
        )
    }

    func frameScaleBinding() -> Binding<Double> {
        Binding(
            get: { self.frames.scaleValue },
            set: {
                self.frames.scaleValue = $0
                self.markEditingConfigurationChanged()
            }
        )
    }

    func colorCorrectionBinding() -> Binding<ColorCorrection> {
        Binding(
            get: { self.currentVideo?.colorCorrection ?? .init() },
            set: { self.setCorrections($0) }
        )
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
        selectedAudioTrack = .video
        videoPlayer.loadState = .loaded(url)
        setNewVideo(url, containerSize: lastPlayerContainerSize)
    }

    func presentExporter() {
        exportSheetTask?.cancel()
        selectedTools = nil
        markEditingConfigurationChanged()
        exportSheetTask = Task { @MainActor [self] in
            defer { exportSheetTask = nil }

            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            showVideoQualitySheet = true
        }
    }

    func cancelDeferredTasks() {
        exportSheetTask?.cancel()
        exportSheetTask = nil
    }

    func currentEditingConfiguration(currentTimelineTime: Double? = nil) -> VideoEditingConfiguration? {
        guard var currentVideo else { return nil }

        currentVideo.videoFrames = frames.isActive ? frames : nil

        return VideoEditingConfigurationMapper.makeConfiguration(
            from: currentVideo,
            freeformRect: cropFreeformRect,
            canvasSnapshot: canvasEditorState.snapshot(),
            selectedAudioTrack: selectedAudioTrack,
            selectedTool: selectedTools,
            socialVideoDestination: socialVideoDestination,
            showsSafeAreaGuides: showsSafeAreaOverlay,
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
        syncCropToolState()
        markEditingConfigurationChanged()
    }

    func resetCanvasTransform() {
        canvasEditorState.resetTransform()
        handleCanvasPreviewChange()
    }

    func playerContainerSize(in availableSize: CGSize) -> CGSize {
        CGSize(
            width: max(availableSize.width - 32, 1),
            height: playerHeight(in: availableSize)
        )
    }

    func prepareEditingConfigurationForInitialLoad(
        _ editingConfiguration: VideoEditingConfiguration?,
        videoPlayer: VideoPlayerManager
    ) {
        pendingEditingConfiguration = editingConfiguration
        selectedTools = nil
        selectedAudioTrack = .video
        cropFreeformRect = nil
        socialVideoDestination = nil
        showsSafeAreaOverlay = false
        canvasEditorState.restore(.initial)

        guard let editingConfiguration else { return }

        if let currentTimelineTime = editingConfiguration.playback.currentTimelineTime {
            videoPlayer.currentTime = currentTimelineTime
        }
    }

    func applyPendingEditingConfiguration(
        to video: inout Video,
        containerSize: CGSize = .zero
    ) {
        guard let pendingEditingConfiguration else { return }

        VideoEditingConfigurationMapper.apply(pendingEditingConfiguration, to: &video)

        let resolvedLayoutSize = resolvedPlayerDisplaySize(
            for: video,
            in: containerSize
        )
        if resolvedLayoutSize.width > 0, resolvedLayoutSize.height > 0 {
            video.frameSize = resolvedLayoutSize
            video.geometrySize = resolvedLayoutSize
        }
    }

    func restorePendingEditingPresentationState() async {
        guard let pendingEditingConfiguration else { return }

        cropFreeformRect = pendingEditingConfiguration.crop.freeformRect
        socialVideoDestination = pendingEditingConfiguration.presentation.socialVideoDestination
        showsSafeAreaOverlay = pendingEditingConfiguration.presentation.showsSafeAreaGuides
        canvasEditorState.restore(
            await resolvedCanvasSnapshot(
                from: pendingEditingConfiguration
            )
        )

        let selectedAudioTrack = VideoEditingConfigurationMapper.selectedAudioTrack(
            from: pendingEditingConfiguration
        )
        if selectedAudioTrack == .recorded, currentVideo?.audio == nil {
            self.selectedAudioTrack = .video
        } else {
            self.selectedAudioTrack = selectedAudioTrack
        }

        if let selectedTool = pendingEditingConfiguration.presentation.selectedTool,
            canSelectTool(selectedTool)
        {
            selectedTools = selectedTool
        } else {
            selectedTools = nil
        }

        self.pendingEditingConfiguration = nil
    }

}

extension EditorViewModel {

    // MARK: - Private Methods

    private func canSelectTool(_ tool: ToolEnum?) -> Bool {
        guard let tool else { return true }
        return enabledTools.contains(tool)
    }

    private func syncCropToolState() {
        guard let currentVideo else { return }

        let hasRotation = abs(currentVideo.rotation.truncatingRemainder(dividingBy: 360)) > 0.001
        let hasMirror = currentVideo.isMirror
        let hasFreeformRect = cropFreeformRect != nil
        let hasCanvasState = canvasEditorState.snapshot().isIdentity == false

        if hasRotation || hasMirror || hasFreeformRect || hasCanvasState {
            self.currentVideo?.appliedTool(for: .presets)
        } else {
            self.currentVideo?.removeTool(for: .presets)
        }
    }

    private func currentCropReferenceSize() -> CGSize? {
        guard let currentVideo else { return nil }
        return resolvedCropReferenceSize(for: currentVideo)
    }

    private func resolvedCropReferenceSize(for video: Video) -> CGSize {
        let resolvedSize = rotatedBaseSize(for: video)
        if resolvedSize.width > 0, resolvedSize.height > 0 {
            return resolvedSize
        }

        if video.geometrySize.width > 0, video.geometrySize.height > 0 {
            return video.geometrySize
        }

        if video.frameSize.width > 0, video.frameSize.height > 0 {
            return video.frameSize
        }

        let fittedPreviewSize = resolvedPlayerDisplaySize(
            for: video,
            in: lastPlayerContainerSize
        )
        guard fittedPreviewSize.width > 0, fittedPreviewSize.height > 0 else {
            return CGSize(
                width: max(lastPlayerContainerSize.width, 1),
                height: max(lastPlayerContainerSize.height, 1)
            )
        }

        return fittedPreviewSize
    }

    private func playerHeight(in availableSize: CGSize) -> CGFloat {
        let heightRatio = 0.40
        let proposedHeight = availableSize.height * heightRatio
        return max(220, proposedHeight)
    }

    private func fittedSize(_ size: CGSize, in bounds: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return bounds }
        guard bounds.width > 0, bounds.height > 0 else { return size }

        let widthScale = bounds.width / size.width
        let heightScale = bounds.height / size.height
        let scale = min(widthScale, heightScale, 1)

        return CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    private func fittedAspectSize(
        for aspectRatio: CGFloat,
        in bounds: CGSize
    ) -> CGSize {
        guard aspectRatio > 0 else { return .zero }
        guard bounds.width > 0, bounds.height > 0 else { return .zero }

        let boundsAspectRatio = bounds.width / bounds.height

        if boundsAspectRatio > aspectRatio {
            let height = bounds.height
            return CGSize(
                width: height * aspectRatio,
                height: height
            )
        }

        let width = bounds.width
        return CGSize(
            width: width,
            height: width / aspectRatio
        )
    }

    private func activeCropViewportAspectRatio(
        in referenceSize: CGSize
    ) -> CGFloat? {
        guard
            let previewLayout = VideoCropPreviewLayout(
                freeformRect: cropFreeformRect,
                in: referenceSize
            ),
            previewLayout.presetSourceRect.width > 0,
            previewLayout.presetSourceRect.height > 0
        else { return nil }

        return previewLayout.presetSourceRect.width / previewLayout.presetSourceRect.height
    }

    private func rotatedBaseSize(for video: Video) -> CGSize {
        let baseSize: CGSize

        if video.presentationSize.width > 0, video.presentationSize.height > 0 {
            baseSize = video.presentationSize
        } else {
            baseSize = video.frameSize
        }

        guard baseSize.width > 0, baseSize.height > 0 else { return .zero }

        let normalizedRotation = abs(Int(video.rotation)) % 180

        if normalizedRotation == 90 {
            return CGSize(width: baseSize.height, height: baseSize.width)
        }

        return baseSize
    }

    private func canvasPreset(
        for preset: VideoCropFormatPreset
    ) -> VideoCanvasPreset {
        switch preset {
        case .original:
            .original
        case .vertical9x16:
            if let socialVideoDestination {
                .social(platform: socialVideoDestination.socialPlatform)
            } else {
                .story
            }
        case .square1x1:
            .custom(width: 1080, height: 1080)
        case .portrait4x5:
            .facebookPost
        case .landscape16x9:
            .custom(width: 1920, height: 1080)
        }
    }

    private func selectedCropPresetFromCanvas() -> VideoCropFormatPreset {
        switch canvasEditorState.preset {
        case .original,
            .free:
            .original
        case .social,
            .story:
            .vertical9x16
        case .facebookPost:
            .portrait4x5
        case .custom(let width, let height):
            switch normalizedPresetKey(width: width, height: height) {
            case "1:1":
                .square1x1
            case "16:9":
                .landscape16x9
            case "9:16":
                .vertical9x16
            case "4:5":
                .portrait4x5
            default:
                .original
            }
        }
    }

    private func normalizedPresetKey(
        width: Int,
        height: Int
    ) -> String {
        guard width > 0, height > 0 else { return "0:0" }
        let divisor = greatestCommonDivisor(width, height)
        return "\(width / divisor):\(height / divisor)"
    }

    private func greatestCommonDivisor(
        _ lhs: Int,
        _ rhs: Int
    ) -> Int {
        var lhs = abs(lhs)
        var rhs = abs(rhs)

        while rhs != 0 {
            let remainder = lhs % rhs
            lhs = rhs
            rhs = remainder
        }

        return max(lhs, 1)
    }

    private func shouldRenderSafeAreaOverlay(
        for preset: VideoCanvasPreset
    ) -> Bool {
        showsSafeAreaOverlay && resolvedSafeAreaGuideProfile(for: preset) != nil
    }

    private func resolvedSafeAreaGuideProfile() -> SafeAreaGuideProfile? {
        resolvedSafeAreaGuideProfile(for: canvasEditorState.preset)
    }

    private func resolvedSafeAreaGuideProfile(
        for preset: VideoCanvasPreset
    ) -> SafeAreaGuideProfile? {
        switch preset {
        case .social(let platform):
            .platform(platform)
        case .story:
            .universalSocial
        case .original,
            .free,
            .custom,
            .facebookPost:
            nil
        }
    }

    private func resolvedCanvasSnapshot(
        from configuration: VideoEditingConfiguration
    ) async -> VideoCanvasSnapshot {
        if configuration.canvas.snapshot != .initial {
            return configuration.canvas.snapshot
        }

        var snapshot = VideoCanvasSnapshot(
            preset: VideoCanvasPreset.fromLegacySelection(
                preset: selectedLegacyCropPreset(
                    from: configuration.crop.freeformRect,
                    referenceSize: currentCropReferenceSize() ?? .zero
                ),
                socialVideoDestination: configuration.presentation.socialVideoDestination
            ),
            showsSafeAreaOverlay: configuration.presentation.showsSafeAreaGuides
        )

        guard let referenceSize = currentCropReferenceSize() else {
            return snapshot
        }

        let mappingActor = VideoCanvasMappingActor()
        let resolvedPreset = mappingActor.resolvePreset(
            snapshot.preset,
            naturalSize: referenceSize,
            freeCanvasSize: snapshot.freeCanvasSize
        )

        snapshot.freeCanvasSize = resolvedPreset.exportSize
        snapshot.transform = mappingActor.snapshotTransform(
            fromLegacyFreeformRect: configuration.crop.freeformRect,
            referenceSize: referenceSize,
            exportSize: resolvedPreset.exportSize
        )

        return snapshot
    }

    private func selectedLegacyCropPreset(
        from freeformRect: VideoEditingConfiguration.FreeformRect?,
        referenceSize: CGSize
    ) -> VideoCropFormatPreset {
        guard referenceSize.width > 0, referenceSize.height > 0 else {
            return freeformRect == nil ? .original : .vertical9x16
        }

        guard let freeformRect else { return .original }
        guard
            let cropRect = VideoCropPreviewLayout.resolvedGeometry(
                freeformRect: freeformRect,
                in: referenceSize
            )?.sourceRect,
            cropRect.width > 0,
            cropRect.height > 0
        else {
            return .vertical9x16
        }

        let aspectRatio = cropRect.width / cropRect.height

        for preset in VideoCropFormatPreset.editorPresets {
            guard let presetAspectRatio = preset.aspectRatio else { continue }
            if abs(aspectRatio - presetAspectRatio) < 0.001 {
                return preset
            }
        }

        return .vertical9x16
    }

    private func markEditingConfigurationChanged() {
        editingConfigurationChangeCounter += 1
    }

}
