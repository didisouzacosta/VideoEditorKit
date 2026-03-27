//
//  VideoPlayerManager.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import AVKit
import Combine
@preconcurrency import CoreImage
import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class VideoPlayerManager {

    // MARK: - Public Properties

    var currentTime: Double = .zero
    var selectedItem: PhotosPickerItem?
    var loadState: LoadState = .unknown {
        didSet {
            guard loadState != oldValue else { return }
            handleLoadStateChange(loadState)
        }
    }
    private(set) var videoPlayer = AVPlayer()
    private(set) var audioPlayer = AVPlayer()
    private(set) var isPlaying = false

    var scrubState: PlayerScrubState = .reset {
        didSet {
            switch scrubState {
            case .scrubEnded(let seekTime):
                pause()
                seek(sourceTime(forTimelineTime: seekTime), player: videoPlayer)
                if isSetAudio {
                    seek(sourceTime(forTimelineTime: seekTime), player: audioPlayer)
                }
                currentTime = seekTime
            default: break
            }
        }
    }

    // MARK: - Private Properties

    private var isSetAudio = false
    private var statusCancellable: AnyCancellable?
    private var timeObserver: Any?
    private var currentDurationRange: ClosedRange<Double>?
    private var currentPlaybackRate: Float = 1
    private var currentOriginalDuration: Double = .zero
    private var endPlaybackObserver: NSObjectProtocol?
    private var filterCompositionTask: Task<Void, Never>?
    private var previewMainFilterName: String?
    private var previewColorCorrection = ColorCorrection()
    private var appliedFilterSignature: String?
    private var appliedFilterItemID: ObjectIdentifier?

    // MARK: - Public Methods

    func action(_ video: Video) {
        syncPlaybackState(with: video)
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func syncPlaybackState(with video: Video, previousRate: Float? = nil) {
        let referenceRate = normalizedPlaybackRate(previousRate ?? currentPlaybackRate)
        currentDurationRange = video.outputRangeDuration
        currentPlaybackRate = normalizedPlaybackRate(video.rate)
        currentOriginalDuration = max(video.originalDuration, .zero)
        setAudio(video.audio?.url)
        videoPlayer.volume = video.volume
        audioPlayer.volume = video.audio?.volume ?? 1

        let clampedTime = video.timelineTimePreservingSourcePosition(
            currentTime,
            fromRate: referenceRate
        )
        currentTime = clampedTime

        guard !isPlaying else { return }

        seek(sourceTime(forTimelineTime: clampedTime), player: videoPlayer)
        if isSetAudio {
            seek(sourceTime(forTimelineTime: clampedTime), player: audioPlayer)
        }
    }

    func setAudio(_ url: URL?) {
        guard let url else {
            isSetAudio = false
            audioPlayer = AVPlayer()
            return
        }
        audioPlayer = .init(url: url)
        isSetAudio = true
    }

    func pause() {
        videoPlayer.pause()
        if isSetAudio {
            audioPlayer.pause()
        }
        isPlaying = false
        syncCurrentTimeFromPlayer()
    }

    func setVolume(_ isVideo: Bool, value: Float) {
        pause()
        if isVideo {
            videoPlayer.volume = value
        } else {
            audioPlayer.volume = value
        }
    }

    func updatePlaybackRange(_ range: ClosedRange<Double>) {
        currentDurationRange = range

        let playbackTime = videoPlayer.currentTime().seconds
        let referenceTime = playbackTime.isFinite ? timelineTime(fromSourceTime: playbackTime) : currentTime
        let clampedTime = referenceTime.clamped(to: range)

        currentTime = clampedTime

        guard !playbackTime.isFinite || abs(referenceTime - clampedTime) > 0.01 else { return }

        seek(sourceTime(forTimelineTime: clampedTime), player: videoPlayer)
        if isSetAudio {
            seek(sourceTime(forTimelineTime: clampedTime), player: audioPlayer)
        }
    }

    func beginScrubbing(in range: ClosedRange<Double>) {
        currentDurationRange = range
        scrubState = .scrubStarted
        pause()
    }

    func scrub(to time: Double, in range: ClosedRange<Double>) {
        currentDurationRange = range
        let clampedTime = time.clamped(to: range)

        currentTime = clampedTime
        seek(sourceTime(forTimelineTime: clampedTime), player: videoPlayer)

        if isSetAudio {
            seek(sourceTime(forTimelineTime: clampedTime), player: audioPlayer)
        }
    }

    func endScrubbing(at time: Double, in range: ClosedRange<Double>) {
        currentDurationRange = range
        let clampedTime = time.clamped(to: range)

        currentTime = clampedTime
        scrubState = .scrubEnded(clampedTime)
    }

    func currentTimeBinding() -> Binding<Double> {
        Binding(
            get: { self.currentTime },
            set: { self.currentTime = $0 }
        )
    }

    // MARK: - Private Methods

    private func handleLoadStateChange(_ loadState: LoadState) {
        switch loadState {
        case .loaded(let url):
            pause()
            cleanupObservers()
            currentDurationRange = nil
            currentPlaybackRate = 1
            currentOriginalDuration = .zero
            currentTime = .zero
            videoPlayer = AVPlayer(url: url)
            startStatusSubscriptions()
            appliedFilterItemID = nil
            applyCurrentFilterComposition()
        case .failed, .loading, .unknown:
            break
        }
    }

    private func startStatusSubscriptions() {
        statusCancellable?.cancel()
        statusCancellable = videoPlayer.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .playing:
                    self.isPlaying = true
                    self.startTimer()
                case .paused:
                    self.isPlaying = false
                case .waitingToPlayAtSpecifiedRate:
                    break
                @unknown default:
                    break
                }
            }
    }

    private func play() {
        AVAudioSession.sharedInstance().configurePlaybackSession()

        if let currentDurationRange {
            let currentPlaybackTime = timelineTime(fromSourceTime: videoPlayer.currentTime().seconds)
            let targetTime = currentTime.clamped(to: currentDurationRange)
            let shouldSeekToRangeStart =
                !currentPlaybackTime.isFinite
                || !currentDurationRange.contains(targetTime)
                || currentPlaybackTime < currentDurationRange.lowerBound
                || currentPlaybackTime >= currentDurationRange.upperBound

            if shouldSeekToRangeStart {
                seek(sourceTime(forTimelineTime: currentDurationRange.lowerBound), player: videoPlayer)
                if isSetAudio {
                    seek(sourceTime(forTimelineTime: currentDurationRange.lowerBound), player: audioPlayer)
                }
                currentTime = currentDurationRange.lowerBound
            } else {
                seek(sourceTime(forTimelineTime: targetTime), player: videoPlayer)
                if isSetAudio {
                    seek(sourceTime(forTimelineTime: targetTime), player: audioPlayer)
                }
                currentTime = targetTime
            }
        }
        videoPlayer.play()
        if isSetAudio {
            audioPlayer.play()
            audioPlayer.rate = currentPlaybackRate
        }

        videoPlayer.rate = currentPlaybackRate

        registerPlaybackObserverIfNeeded()
    }

    private func seek(_ seconds: Double, player: AVPlayer) {
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    private func startTimer() {
        removeTimeObserver()
        let interval = CMTimeMake(value: 1, timescale: 30)
        timeObserver = videoPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isPlaying {
                    let playbackTime = time.seconds
                    let resolvedTime = self.resolvedCurrentTime(from: playbackTime)

                    if let currentDurationRange = self.currentDurationRange,
                        playbackTime >= self.sourceTime(forTimelineTime: currentDurationRange.upperBound)
                    {
                        self.currentTime = currentDurationRange.upperBound
                        self.pause()
                        return
                    }

                    switch self.scrubState {
                    case .reset:
                        self.currentTime = resolvedTime
                    case .scrubEnded:
                        self.scrubState = .reset
                    case .scrubStarted:
                        break
                    }
                }
            }
        }
    }

    private func registerPlaybackObserverIfNeeded() {
        removeEndPlaybackObserver()

        guard let currentDurationRange,
            videoPlayer.currentItem?.duration.seconds ?? 0
                >= sourceTime(forTimelineTime: currentDurationRange.upperBound)
        else {
            return
        }

        endPlaybackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: videoPlayer.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playerDidFinishPlaying()
            }
        }
    }

    private func playerDidFinishPlaying() {
        let restartTime = currentDurationRange?.lowerBound ?? .zero
        pause()
        seek(sourceTime(forTimelineTime: restartTime), player: videoPlayer)
        if isSetAudio {
            seek(sourceTime(forTimelineTime: restartTime), player: audioPlayer)
        }
        currentTime = restartTime
    }

    private func removeTimeObserver() {
        if let timeObserver = timeObserver {
            videoPlayer.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private func removeEndPlaybackObserver() {
        if let endPlaybackObserver {
            NotificationCenter.default.removeObserver(endPlaybackObserver)
            self.endPlaybackObserver = nil
        }
    }

    private func cleanupObservers() {
        removeTimeObserver()
        removeEndPlaybackObserver()
        statusCancellable?.cancel()
        statusCancellable = nil
    }

    private func resolvedCurrentTime(from playbackTime: Double) -> Double {
        guard playbackTime.isFinite else {
            return currentDurationRange.map { currentTime.clamped(to: $0) } ?? currentTime
        }

        let timelinePlaybackTime = timelineTime(fromSourceTime: playbackTime)

        guard let currentDurationRange else { return timelinePlaybackTime }
        return timelinePlaybackTime.clamped(to: currentDurationRange)
    }

    private func syncCurrentTimeFromPlayer() {
        currentTime = resolvedCurrentTime(from: videoPlayer.currentTime().seconds)
    }

    private func normalizedPlaybackRate(_ rate: Float) -> Float {
        guard rate.isFinite, rate > 0 else { return 1 }
        return rate
    }

    private func sourceTime(forTimelineTime time: Double) -> Double {
        PlaybackTimeMapping.sourceTime(
            forTimelineTime: time,
            rate: currentPlaybackRate,
            originalDuration: currentOriginalDuration
        )
    }

    private func timelineTime(fromSourceTime time: Double) -> Double {
        PlaybackTimeMapping.timelineTime(
            fromSourceTime: time,
            rate: currentPlaybackRate
        )
    }

}

extension VideoPlayerManager {

    // MARK: - Public Methods

    @MainActor
    func loadVideoItem(_ selectedItem: PhotosPickerItem?) async {
        do {
            loadState = .loading

            if let video = try await selectedItem?.loadTransferable(type: VideoItem.self) {
                loadState = .loaded(video.url)
            } else {
                loadState = .failed
            }
        } catch {
            loadState = .failed
        }
    }

}

extension VideoPlayerManager {

    // MARK: - Public Methods

    func setFilters(mainFilter: CIFilter?, colorCorrection: ColorCorrection?) {
        previewMainFilterName = mainFilter?.name
        previewColorCorrection = colorCorrection ?? .init()

        applyCurrentFilterComposition()
    }

    func removeFilter() {
        previewMainFilterName = nil
        applyCurrentFilterComposition()
    }

    // MARK: - Private Methods

    private func applyCurrentFilterComposition() {
        filterCompositionTask?.cancel()

        guard let currentItem = videoPlayer.currentItem else {
            appliedFilterSignature = nil
            appliedFilterItemID = nil
            return
        }

        let currentItemID = ObjectIdentifier(currentItem)
        let signature = currentFilterSignature()

        if signature == nil {
            guard appliedFilterSignature != nil || appliedFilterItemID != currentItemID else {
                return
            }

            pause()
            currentItem.videoComposition = nil
            appliedFilterSignature = nil
            appliedFilterItemID = currentItemID
            return
        }

        guard appliedFilterSignature != signature || appliedFilterItemID != currentItemID else {
            return
        }

        let filters = Helpers.createFilters(
            previewMainFilterName.flatMap(CIFilter.init(name:)),
            colorCorrection: previewColorCorrection.isIdentity ? nil : previewColorCorrection
        )

        guard !filters.isEmpty else {
            currentItem.videoComposition = nil
            appliedFilterSignature = nil
            appliedFilterItemID = currentItemID
            return
        }

        pause()

        filterCompositionTask = Task { [weak self] in
            guard let composition = try? await currentItem.asset.setFilters(filters) else { return }
            await MainActor.run {
                guard let self, self.videoPlayer.currentItem === currentItem else { return }
                currentItem.videoComposition = composition
                self.appliedFilterSignature = signature
                self.appliedFilterItemID = currentItemID
            }
        }
    }

    private func currentFilterSignature() -> String? {
        guard previewMainFilterName != nil || !previewColorCorrection.isIdentity else { return nil }

        return [
            previewMainFilterName ?? "none",
            String(previewColorCorrection.brightness),
            String(previewColorCorrection.contrast),
            String(previewColorCorrection.saturation),
        ]
        .joined(separator: "|")
    }

}

enum LoadState: Identifiable, Equatable {
    // MARK: - Public Properties

    case unknown, loading

    case loaded(URL)

    case failed

    var id: Int {
        switch self {
        case .unknown: return 0
        case .loading: return 1
        case .loaded: return 2
        case .failed: return 3
        }
    }
}

enum PlayerScrubState {
    // MARK: - Public Properties

    case reset

    case scrubStarted

    case scrubEnded(Double)
}

extension AVAsset {

    // MARK: - Public Methods

    func setFilter(_ filter: CIFilter) async throws -> AVVideoComposition {
        try await withCheckedThrowingContinuation { continuation in
            AVVideoComposition.videoComposition(
                with: self,
                applyingCIFiltersWithHandler: { request in
                    filter.setValue(request.sourceImage, forKey: kCIInputImageKey)

                    guard let output = filter.outputImage else {
                        request.finish(with: request.sourceImage, context: nil)
                        return
                    }

                    request.finish(with: output, context: nil)
                },
                completionHandler: { composition, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let composition {
                        continuation.resume(returning: composition)
                    } else {
                        continuation.resume(throwing: VideoCompositionError.creationFailed)
                    }
                })
        }
    }

    func setFilters(_ filters: [CIFilter]) async throws -> AVVideoComposition {
        try await withCheckedThrowingContinuation { continuation in
            AVVideoComposition.videoComposition(
                with: self,
                applyingCIFiltersWithHandler: { request in

                    let source = request.sourceImage
                    var output = source

                    for filter in filters {
                        filter.setValue(output, forKey: kCIInputImageKey)
                        if let image = filter.outputImage {
                            output = image
                        }
                    }

                    request.finish(with: output, context: nil)
                },
                completionHandler: { composition, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let composition {
                        continuation.resume(returning: composition)
                    } else {
                        continuation.resume(throwing: VideoCompositionError.creationFailed)
                    }
                })
        }
    }

}

private enum VideoCompositionError: Error {
    case creationFailed
}
