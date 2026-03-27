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
    var selectedTools: ToolEnum?
    var frames = VideoFrames()
    var isSelectVideo = true
    var showVideoQualitySheet = false
    var showRecordView = false
    var cropTab: CropToolTab = .rotate
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

    enum CropToolTab: String, CaseIterable {
        case format, rotate
    }

    // MARK: - Private Properties

    @ObservationIgnored private var loadVideoTask: Task<Void, Never>?
    @ObservationIgnored private var thumbnailsTask: Task<Void, Never>?
    @ObservationIgnored private var exportSheetTask: Task<Void, Never>?

    private var hasLoadedSourceVideo = false
    private var lastPlayerContainerSize = CGSize(width: 1, height: 220)
    private var lastThumbnailDisplayScale: CGFloat = 1

    // MARK: - Public Methods

    func setNewVideo(_ url: URL, containerSize: CGSize) {
        loadVideoTask?.cancel()
        thumbnailsTask?.cancel()
        currentVideo = nil
        lastPlayerContainerSize = containerSize

        loadVideoTask = Task { [weak self] in
            let video = await Video.load(from: url)
            guard !Task.isCancelled else { return }

            self?.currentVideo = video
            self?.loadThumbnails(
                for: video,
                containerSize: containerSize,
                displayScale: self?.lastThumbnailDisplayScale ?? 1
            )
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

//MARK: - Tools logic
extension EditorViewModel {

    // MARK: - Public Methods

    func setFilter(_ filter: String?) {
        currentVideo?.setFilter(filter)
        if filter != nil {
            setTools()
        } else {
            removeTool()
        }
    }

    func setText(_ textBox: [TextBox]) {
        currentVideo?.textBoxes = textBox
        setTools()
    }

    func setFrames() {
        currentVideo?.videoFrames = frames
        setTools()
    }

    func setCorrections(_ correction: ColorCorrection) {
        currentVideo?.colorCorrection = correction
        setTools()
    }

    func updateRate(rate: Float) {
        currentVideo?.updateRate(rate)
        setTools()
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
    }

    func resetCut() {
        currentVideo?.resetRangeDuration()
        currentVideo?.removeTool(for: .cut)
    }

    func rotate() {
        currentVideo?.rotate()
        setTools()
    }

    func setRotation(_ rotation: Double) {
        guard currentVideo?.rotation != rotation else { return }
        currentVideo?.rotation = rotation
        setTools()
    }

    func toggleMirror() {
        currentVideo?.isMirror.toggle()
        setTools()
    }

    func setAudio(_ audio: Audio) {
        currentVideo?.audio = audio
        setTools()
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
        isSelectVideo = true
        removeTool()
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
            currentVideo?.resetRate()
        case .crop:
            currentVideo?.rotation = 0
            currentVideo?.isMirror = false
            cropTab = .rotate
        case .audio:
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

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            self?.currentVideo?.removeTool(for: tool)
        }
    }

    func selectTool(_ tool: ToolEnum) {
        selectedTools = tool
    }

    func closeSelectedTool(textEditor: TextEditorViewModel) {
        selectedTools = nil
        setText(textEditor.textBoxes)
    }

    func handleCurrentVideoChange(
        _ video: Video?,
        filtersViewModel: FiltersViewModel,
        textEditor: TextEditorViewModel
    ) {
        guard let video else { return }
        filtersViewModel.sync(with: video)
        textEditor.load(textBoxes: video.textBoxes)
    }

    func handleThumbnailImagesChange(filtersViewModel: FiltersViewModel) {
        filtersViewModel.loadFiltersIfNeeded(from: currentVideo?.thumbnailsImages.first?.image)
    }

    func handleSelectedTextBoxChange(_ box: TextBox?) {
        if box != nil {
            if selectedTools != .text {
                selectedTools = .text
            }
        } else if selectedTools == .text {
            selectedTools = nil
        }
    }

    func handleSelectedToolChange(_ tool: ToolEnum?, textEditor: TextEditorViewModel) {
        if tool == .text {
            textEditor.prepareForToolPresentation(timeRange: currentVideo?.rangeDuration)
        }

        if tool == nil {
            setText(textEditor.textBoxes)
        }
    }

    func handleRateChange(_ rate: Float, videoPlayer: VideoPlayerManager) {
        videoPlayer.pause()
        updateRate(rate: rate)
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

    func removeAudio(using videoPlayer: VideoPlayerManager) {
        videoPlayer.pause()
        removeAudio()
    }

    func updateSelectedTrackVolume(_ value: Float, videoPlayer: VideoPlayerManager) {
        if isSelectVideo {
            currentVideo?.setVolume(value)
        } else {
            currentVideo?.audio?.setVolume(value)
        }

        videoPlayer.setVolume(isSelectVideo, value: value)
    }

    func selectedTrackVolume() -> Float {
        if isSelectVideo {
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

    func frameColorBinding() -> Binding<Color> {
        Binding(
            get: { self.frames.frameColor },
            set: { self.frames.frameColor = $0 }
        )
    }

    func frameScaleBinding() -> Binding<Double> {
        Binding(
            get: { self.frames.scaleValue },
            set: { self.frames.scaleValue = $0 }
        )
    }

    func setSourceVideoIfNeeded(
        _ sourceVideoURL: URL?,
        availableSize: CGSize,
        videoPlayer: VideoPlayerManager
    ) {
        let containerSize = playerContainerSize(in: availableSize)
        lastPlayerContainerSize = containerSize

        guard !hasLoadedSourceVideo, let sourceVideoURL else { return }
        hasLoadedSourceVideo = true
        videoPlayer.loadState = .loaded(sourceVideoURL)
        setNewVideo(sourceVideoURL, containerSize: containerSize)
    }

    func handleRecordedVideo(_ url: URL, videoPlayer: VideoPlayerManager) {
        hasLoadedSourceVideo = true
        videoPlayer.loadState = .loaded(url)
        setNewVideo(url, containerSize: lastPlayerContainerSize)
    }

    func presentExporter() {
        exportSheetTask?.cancel()
        selectedTools = nil
        exportSheetTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.showVideoQualitySheet = true
        }
    }

    func cancelDeferredTasks() {
        exportSheetTask?.cancel()
        exportSheetTask = nil
    }

    func playerContainerSize(in availableSize: CGSize) -> CGSize {
        CGSize(
            width: max(availableSize.width - 32, 1),
            height: playerHeight(in: availableSize)
        )
    }

}

extension EditorViewModel {

    // MARK: - Private Methods

    private func playerHeight(in availableSize: CGSize) -> CGFloat {
        let heightRatio = 0.40
        let proposedHeight = availableSize.height * heightRatio
        return max(220, proposedHeight)
    }

}
