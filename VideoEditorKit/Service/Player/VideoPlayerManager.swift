//
//  VideoPlayerManager.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import Combine
import AVKit
import PhotosUI
import SwiftUI
@preconcurrency import CoreImage

@MainActor
final class VideoPlayerManager: ObservableObject {
    @Published var currentTime: Double = .zero
    @Published var selectedItem: PhotosPickerItem?
    @Published var loadState: LoadState = .unknown {
        didSet {
            guard loadState != oldValue else { return }
            handleLoadStateChange(loadState)
        }
    }
    @Published private(set) var videoPlayer = AVPlayer()
    @Published private(set) var audioPlayer = AVPlayer()
    @Published private(set) var isPlaying = false

    private var isSetAudio = false
    private var statusCancellable: AnyCancellable?
    private var timeObserver: Any?
    private var currentDurationRange: ClosedRange<Double>?
    private var endPlaybackObserver: NSObjectProtocol?
    private var filterCompositionTask: Task<Void, Never>?
    
    var scrubState: PlayerScrubState = .reset {
        didSet {
            switch scrubState {
            case .scrubEnded(let seekTime):
                pause()
                seek(seekTime, player: videoPlayer)
                if isSetAudio{
                    seek(seekTime, player: audioPlayer)
                }
            default : break
            }
        }
    }
    
    func action(_ video: Video){
        self.currentDurationRange = video.rangeDuration
        if isPlaying{
            pause()
        }else{
            play(video.rate)
        }
    }
    
    func setAudio(_ url: URL?){
        guard let url else {
            isSetAudio = false
            audioPlayer = AVPlayer()
            return
        }
        audioPlayer = .init(url: url)
        isSetAudio = true
    }
    
    private func handleLoadStateChange(_ loadState: LoadState) {
        switch loadState {
        case .loaded(let url):
            pause()
            cleanupObservers()
            videoPlayer = AVPlayer(url: url)
            startStatusSubscriptions()
        case .failed, .loading, .unknown:
            break
        }
    }
    
    private func startStatusSubscriptions(){
        statusCancellable?.cancel()
        statusCancellable = videoPlayer.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else {return}
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
    
    func pause(){
        videoPlayer.pause()
        if isSetAudio{
            audioPlayer.pause()
        }
    }
    
    func setVolume(_ isVideo: Bool, value: Float){
        pause()
        if isVideo{
            videoPlayer.volume = value
        }else{
            audioPlayer.volume = value
        }
    }

    private func play(_ rate: Float?){
        AVAudioSession.sharedInstance().configurePlaybackSession()
        
        if let currentDurationRange{
            if currentTime >= currentDurationRange.upperBound{
                seek(currentDurationRange.lowerBound, player: videoPlayer)
                if isSetAudio{
                    seek(currentDurationRange.lowerBound, player: audioPlayer)
                }
            }else{
                seek(videoPlayer.currentTime().seconds, player: videoPlayer)
                if isSetAudio{
                    seek(audioPlayer.currentTime().seconds, player: audioPlayer)
                }
            }
        }
        videoPlayer.play()
        if isSetAudio{
            audioPlayer.play()
        }
        
        if let rate{
            videoPlayer.rate = rate
        }
        
        registerPlaybackObserverIfNeeded()
    }
    
    private func seek(_ seconds: Double, player: AVPlayer){
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }
    
    private func startTimer() {
        removeTimeObserver()
        let interval = CMTimeMake(value: 1, timescale: 10)
        timeObserver = videoPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isPlaying{
                    let time = time.seconds
                    
                    if let currentDurationRange = self.currentDurationRange, time >= currentDurationRange.upperBound{
                        self.pause()
                    }

                    switch self.scrubState {
                    case .reset:
                        self.currentTime = time
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
              videoPlayer.currentItem?.duration.seconds ?? 0 >= currentDurationRange.upperBound else {
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
        seek(restartTime, player: videoPlayer)
        if isSetAudio {
            seek(restartTime, player: audioPlayer)
        }
        pause()
    }
    
    private func removeTimeObserver(){
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
    
}

extension VideoPlayerManager{
    @MainActor
    func loadVideoItem(_ selectedItem: PhotosPickerItem?) async{
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


extension VideoPlayerManager{
    func setFilters(mainFilter: CIFilter?, colorCorrection: ColorCorrection?){
        let filters = Helpers.createFilters(mainFilter: mainFilter, colorCorrection)
        
        if filters.isEmpty{
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
        
    func removeFilter(){
        filterCompositionTask?.cancel()
        pause()
        videoPlayer.currentItem?.videoComposition = nil
    }
}

enum LoadState: Identifiable, Equatable {
    case unknown, loading, loaded(URL), failed
    
    var id: Int{
        switch self {
        case .unknown: return 0
        case .loading: return 1
        case .loaded: return 2
        case .failed: return 3
        }
    }
}


enum PlayerScrubState{
    case reset
    case scrubStarted
    case scrubEnded(Double)
}


extension AVAsset{
    
    func setFilter(_ filter: CIFilter) async throws -> AVVideoComposition{
        try await withCheckedThrowingContinuation { continuation in
            AVVideoComposition.videoComposition(with: self, applyingCIFiltersWithHandler: { request in
                filter.setValue(request.sourceImage, forKey: kCIInputImageKey)
                
                guard let output = filter.outputImage else {
                    request.finish(with: request.sourceImage, context: nil)
                    return
                }
                
                request.finish(with: output, context: nil)
            }, completionHandler: { composition, error in
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
    
    func setFilters(_ filters: [CIFilter]) async throws -> AVVideoComposition{
        try await withCheckedThrowingContinuation { continuation in
            AVVideoComposition.videoComposition(with: self, applyingCIFiltersWithHandler: { request in
                
                let source = request.sourceImage
                var output = source
                
                filters.forEach { filter in
                    filter.setValue(output, forKey: kCIInputImageKey)
                    if let image = filter.outputImage{
                        output = image
                    }
                }
                
                request.finish(with: output, context: nil)
            }, completionHandler: { composition, error in
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
