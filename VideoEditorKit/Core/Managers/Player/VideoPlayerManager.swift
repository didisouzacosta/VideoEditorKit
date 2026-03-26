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
                seek(seekTime, player: videoPlayer)
                if isSetAudio {
                    seek(seekTime, player: audioPlayer)
                }
            default: break
            }
        }
    }

    // MARK: - Private Properties

    private var isSetAudio = false
    private var statusCancellable: AnyCancellable?
    private var timeObserver: Any?
    private var currentDurationRange: ClosedRange<Double>?
    private var endPlaybackObserver: NSObjectProtocol?
    private var filterCompositionTask: Task<Void, Never>?

    // MARK: - Public Methods

    func action(_ video: Video) {
        self.currentDurationRange = video.rangeDuration
        if isPlaying {
            pause()
        } else {
            play(video.rate)
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
        let referenceTime = playbackTime.isFinite ? playbackTime : currentTime
        let clampedTime = referenceTime.clamped(to: range)

        currentTime = clampedTime

        guard !playbackTime.isFinite || abs(playbackTime - clampedTime) > 0.01 else { return }

        seek(clampedTime, player: videoPlayer)
        if isSetAudio {
            seek(clampedTime, player: audioPlayer)
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
        seek(clampedTime, player: videoPlayer)

        if isSetAudio {
            seek(clampedTime, player: audioPlayer)
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
            currentTime = .zero
            videoPlayer = AVPlayer(url: url)
            startStatusSubscriptions()
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

    private func play(_ rate: Float?) {
        AVAudioSession.sharedInstance().configurePlaybackSession()

        if let currentDurationRange {
            let currentPlaybackTime = videoPlayer.currentTime().seconds
            let shouldSeekToRangeStart =
                !currentDurationRange.contains(currentTime)
                || !currentPlaybackTime.isFinite
                || currentPlaybackTime < currentDurationRange.lowerBound
                || currentPlaybackTime >= currentDurationRange.upperBound

            if shouldSeekToRangeStart {
                seek(currentDurationRange.lowerBound, player: videoPlayer)
                if isSetAudio {
                    seek(currentDurationRange.lowerBound, player: audioPlayer)
                }
                currentTime = currentDurationRange.lowerBound
            } else {
                seek(currentPlaybackTime, player: videoPlayer)
                if isSetAudio {
                    seek(audioPlayer.currentTime().seconds, player: audioPlayer)
                }
            }
        }
        videoPlayer.play()
        if isSetAudio {
            audioPlayer.play()
        }

        if let rate {
            videoPlayer.rate = rate
        }

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
                        playbackTime >= currentDurationRange.upperBound
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
            videoPlayer.currentItem?.duration.seconds ?? 0 >= currentDurationRange.upperBound
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
        seek(restartTime, player: videoPlayer)
        if isSetAudio {
            seek(restartTime, player: audioPlayer)
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

        guard let currentDurationRange else { return playbackTime }
        return playbackTime.clamped(to: currentDurationRange)
    }

    private func syncCurrentTimeFromPlayer() {
        currentTime = resolvedCurrentTime(from: videoPlayer.currentTime().seconds)
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
        let filters = Helpers.createFilters(mainFilter: mainFilter, colorCorrection)

        if filters.isEmpty {
            filterCompositionTask?.cancel()
            return
        }
        pause()
        filterCompositionTask?.cancel()

        guard let currentItem = videoPlayer.currentItem else { return }

        filterCompositionTask = Task { [weak self] in
            guard let composition = try? await currentItem.asset.setFilters(filters) else { return }
            await MainActor.run {
                guard let self, self.videoPlayer.currentItem === currentItem else { return }
                currentItem.videoComposition = composition
            }
        }
    }

    func removeFilter() {
        filterCompositionTask?.cancel()
        pause()
        videoPlayer.currentItem?.videoComposition = nil
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
