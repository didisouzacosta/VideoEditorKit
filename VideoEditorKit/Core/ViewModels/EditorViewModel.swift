//
//  EditorViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import CoreImage
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
    var cropTab: CropToolTab = .rotate
    var cropFreeformRect: VideoEditingConfiguration.FreeformRect?
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
        selectedTools == .crop
            && cropTab == .format
            && cropFreeformRect != nil
    }

    enum CropToolTab: String, CaseIterable {
        case format, rotate
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
    private var pendingTextOverlays: [VideoEditingConfiguration.TextOverlay] = []

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
            self?.restorePendingEditingPresentationState()
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

    // MARK: - Private Methods

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

}

extension EditorViewModel {

    // MARK: - Public Methods

    func setFilter(_ filter: String?) {
        currentVideo?.setFilter(filter)
        if filter != nil {
            setTools()
        } else {
            removeTool()
        }
        markEditingConfigurationChanged()
    }

    func setText(_ textBox: [TextBox]) {
        currentVideo?.textBoxes = textBox
        setTools()
        markEditingConfigurationChanged()
    }

    func setFrames() {
        currentVideo?.videoFrames = frames
        setTools()
        markEditingConfigurationChanged()
    }

    func setCorrections(_ correction: ColorCorrection) {
        currentVideo?.colorCorrection = correction
        setTools()
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

    func selectCropTab(_ tab: CropToolTab) {
        guard cropTab != tab else { return }
        cropTab = tab
        markEditingConfigurationChanged()
    }

    func setCropFreeformRect(_ rect: VideoEditingConfiguration.FreeformRect?) {
        guard cropFreeformRect != rect else { return }
        cropFreeformRect = rect
        syncCropToolState()
        markEditingConfigurationChanged()
    }

    func selectCropFormat(_ preset: VideoCropFormatPreset) {
        let previousCropTab = cropTab
        let previousCropRect = cropFreeformRect
        let nextCropRect: VideoEditingConfiguration.FreeformRect?

        switch preset {
        case .original:
            nextCropRect = nil
        case .vertical9x16:
            guard let referenceSize = currentCropReferenceSize() else { return }
            nextCropRect = preset.makeFreeformRect(for: referenceSize)
        }

        cropTab = .format
        cropFreeformRect = nextCropRect
        syncCropToolState()

        guard previousCropTab != cropTab || previousCropRect != cropFreeformRect else { return }
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
        self.currentVideo?.removeTool(for: selectedTools)
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
        textEditor: TextEditorViewModel,
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
        case .crop:
            currentVideo?.rotation = 0
            currentVideo?.isMirror = false
            cropFreeformRect = nil
            cropTab = .rotate
        case .audio:
            selectedAudioTrack = .video
            if currentVideo?.audio != nil {
                removeAudio(using: videoPlayer)
                return
            }

            currentVideo?.setVolume(1.0)
            videoPlayer.setVolume(true, value: 1.0)
        case .text:
            textEditor.cancelTextEditor()
            textEditor.selectedTextBox = nil
            textEditor.load(textBoxes: [])
            currentVideo?.textBoxes = []
        case .filters:
            currentVideo?.setFilter(nil)
            videoPlayer.removeFilter()
        case .corrections:
            currentVideo?.colorCorrection = ColorCorrection()
            let mainFilter = currentVideo?.filterName.flatMap(CIFilter.init(name:))
            videoPlayer.setFilters(mainFilter: mainFilter, colorCorrection: ColorCorrection())
        case .frames:
            frames.reset()
            currentVideo?.videoFrames = nil
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

    func closeSelectedTool(_ textEditor: TextEditorViewModel) {
        selectedTools = nil
        setText(textEditor.textBoxes)
    }

    func handleCurrentVideoChange(
        _ video: Video?,
        filtersViewModel: FiltersViewModel,
        textEditor: TextEditorViewModel,
        videoPlayer: VideoPlayerManager
    ) {
        guard let video else { return }
        frames = video.videoFrames ?? VideoFrames()
        filtersViewModel.sync(with: video)
        textEditor.load(textBoxes: video.textBoxes)
        videoPlayer.syncPlaybackState(with: video)
        videoPlayer.setFilters(
            mainFilter: video.filterName.flatMap(CIFilter.init(name:)),
            colorCorrection: video.colorCorrection
        )
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

    func updateCurrentVideoLayout(
        to size: CGSize,
        textEditor: TextEditorViewModel
    ) {
        guard var currentVideo else { return }

        let previousGeometrySize = currentVideo.geometrySize
        let didChangeFrameSize = currentVideo.frameSize != size
        let didChangeGeometrySize = currentVideo.geometrySize != size

        guard didChangeFrameSize || didChangeGeometrySize else { return }

        if didChangeGeometrySize {
            currentVideo.textBoxes = VideoEditingConfigurationMapper.rescaledTextBoxes(
                currentVideo.textBoxes,
                from: previousGeometrySize,
                to: size
            )
        }

        currentVideo.frameSize = size
        currentVideo.geometrySize = size
        applyPendingTextOverlaysIfNeeded(to: &currentVideo)

        self.currentVideo = currentVideo

        if didChangeGeometrySize {
            textEditor.load(textBoxes: currentVideo.textBoxes)
        }

        markEditingConfigurationChanged()
    }

    func handleThumbnailImagesChange(filtersViewModel: FiltersViewModel) {
        filtersViewModel.loadFiltersIfNeeded(from: currentVideo?.thumbnailsImages.first?.image)
    }

    func handleSelectedTextBoxChange(_ box: TextBox?) {
        if box != nil {
            if selectedTools != .text {
                selectTool(.text)
            }
        } else if selectedTools == .text {
            selectedTools = nil
            markEditingConfigurationChanged()
        }
    }

    func handleSelectedToolChange(_ tool: ToolEnum?, textEditor: TextEditorViewModel) {
        let previousSelection = selectedTools

        guard tool == nil || canSelectTool(tool) else {
            selectedTools = nil
            if previousSelection != selectedTools {
                markEditingConfigurationChanged()
            }
            return
        }

        if tool != .text {
            textEditor.dismissTextToolPresentation()
        }

        if tool == .text {
            textEditor.prepareForToolPresentation(timeRange: currentVideo?.rangeDuration)
        }

        if tool == nil {
            setText(textEditor.textBoxes)
        }

        if previousSelection != tool {
            markEditingConfigurationChanged()
        }
    }

    func handleRateChange(_ rate: Float, videoPlayer: VideoPlayerManager) {
        let previousRate = currentVideo?.rate ?? 1
        videoPlayer.pause()
        updateRate(rate: rate)
        if let currentVideo {
            videoPlayer.syncPlaybackState(with: currentVideo, previousRate: previousRate)
        }
    }

    func handleFilterChange(
        _ filterName: String?,
        filtersViewModel: FiltersViewModel,
        videoPlayer: VideoPlayerManager
    ) {
        if let filterName {
            videoPlayer.setFilters(
                mainFilter: CIFilter(name: filterName),
                colorCorrection: filtersViewModel.colorCorrection
            )
        } else {
            videoPlayer.removeFilter()
        }

        setFilter(filterName)
    }

    func handleCorrectionsChange(_ corrections: ColorCorrection, videoPlayer: VideoPlayerManager) {
        let mainFilter = currentVideo?.filterName.flatMap(CIFilter.init(name:))
        videoPlayer.setFilters(mainFilter: mainFilter, colorCorrection: corrections)
        setCorrections(corrections)
    }

    func isCropTabSelected(_ tab: CropToolTab) -> Bool {
        cropTab == tab
    }

    func isCropFormatSelected(_ preset: VideoCropFormatPreset) -> Bool {
        guard let referenceSize = currentCropReferenceSize() else {
            return preset == .original && cropFreeformRect == nil
        }

        return preset.matches(cropFreeformRect, in: referenceSize)
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
            selectedAudioTrack: selectedAudioTrack,
            selectedTool: selectedTools,
            cropTab: serializedCropTab(),
            currentTimelineTime: currentTimelineTime
        )
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
        pendingTextOverlays = []
        cropTab = .rotate
        selectedTools = nil
        selectedAudioTrack = .video
        cropFreeformRect = nil

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

        pendingTextOverlays = pendingEditingConfiguration.textOverlays

        var configurationWithoutTextOverlays = pendingEditingConfiguration
        configurationWithoutTextOverlays.textOverlays = []
        VideoEditingConfigurationMapper.apply(configurationWithoutTextOverlays, to: &video)

        let resolvedLayoutSize = resolvedPlayerDisplaySize(
            for: video,
            in: containerSize
        )
        if resolvedLayoutSize.width > 0, resolvedLayoutSize.height > 0 {
            video.frameSize = resolvedLayoutSize
            video.geometrySize = resolvedLayoutSize
        }

        applyPendingTextOverlaysIfNeeded(to: &video)
    }

    func restorePendingEditingPresentationState() {
        guard let pendingEditingConfiguration else { return }

        cropTab = VideoEditingConfigurationMapper.cropTab(from: pendingEditingConfiguration)
        cropFreeformRect = pendingEditingConfiguration.crop.freeformRect

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

        if hasRotation || hasMirror || hasFreeformRect {
            self.currentVideo?.appliedTool(for: .crop)
        } else {
            self.currentVideo?.removeTool(for: .crop)
        }
    }

    private func currentCropReferenceSize() -> CGSize? {
        guard let currentVideo else { return nil }

        let resolvedSize = rotatedBaseSize(for: currentVideo)
        if resolvedSize.width > 0, resolvedSize.height > 0 {
            return resolvedSize
        }

        if currentVideo.geometrySize.width > 0, currentVideo.geometrySize.height > 0 {
            return currentVideo.geometrySize
        }

        if currentVideo.frameSize.width > 0, currentVideo.frameSize.height > 0 {
            return currentVideo.frameSize
        }

        let fittedPreviewSize = resolvedPlayerDisplaySize(
            for: currentVideo,
            in: lastPlayerContainerSize
        )
        guard fittedPreviewSize.width > 0, fittedPreviewSize.height > 0 else { return nil }
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

    private func serializedCropTab() -> VideoEditingConfiguration.CropTab {
        switch cropTab {
        case .format:
            .format
        case .rotate:
            .rotate
        }
    }

    private func applyPendingTextOverlaysIfNeeded(to video: inout Video) {
        guard !pendingTextOverlays.isEmpty else { return }

        VideoEditingConfigurationMapper.applyTextOverlays(
            pendingTextOverlays,
            to: &video
        )

        if video.textBoxes.count == pendingTextOverlays.count {
            pendingTextOverlays = []
        }
    }

    private func markEditingConfigurationChanged() {
        editingConfigurationChangeCounter += 1
    }

}
