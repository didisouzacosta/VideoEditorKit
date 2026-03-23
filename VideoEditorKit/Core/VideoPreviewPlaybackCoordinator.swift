import AVFoundation
import Foundation

@MainActor
protocol VideoPreviewPlayerDriving: AnyObject {
    var player: AVPlayer { get }
    var currentTime: Double { get }
    var isPlaying: Bool { get }

    func loadVideo(from sourceVideoURL: URL)
    func seek(to time: Double)
    func play()
    func pause()
    func setTimeUpdateHandler(_ handler: @escaping (Double) -> Void)
}

@MainActor
final class VideoPreviewPlaybackCoordinator {
    private let driver: any VideoPreviewPlayerDriving
    private let timeTolerance: Double
    private var loadedSourceVideoURL: URL?

    var player: AVPlayer {
        driver.player
    }

    init(
        driver: any VideoPreviewPlayerDriving = AVPlayerPreviewDriver(),
        timeTolerance: Double = 0.05,
        onTimeUpdate: @escaping (Double) -> Void = { _ in }
    ) {
        self.driver = driver
        self.timeTolerance = timeTolerance
        driver.setTimeUpdateHandler(onTimeUpdate)
    }

    func loadVideoIfNeeded(from sourceVideoURL: URL) {
        guard loadedSourceVideoURL != sourceVideoURL else {
            return
        }

        loadedSourceVideoURL = sourceVideoURL
        driver.loadVideo(from: sourceVideoURL)
    }

    func sync(
        currentTime: Double,
        isPlaying: Bool
    ) {
        if abs(driver.currentTime - currentTime) > timeTolerance {
            driver.seek(to: currentTime)
        }

        guard driver.isPlaying != isPlaying else {
            return
        }

        if isPlaying {
            driver.play()
        } else {
            driver.pause()
        }
    }
}

@MainActor
final class AVPlayerPreviewDriver: VideoPreviewPlayerDriving {
    let player = AVPlayer()

    private nonisolated(unsafe) var timeObserverToken: Any?
    private nonisolated(unsafe) var timeUpdateHandler: ((Double) -> Void)?

    init() {
        player.actionAtItemEnd = .pause
        installTimeObserver()
    }

    deinit {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
    }

    var currentTime: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    var isPlaying: Bool {
        player.timeControlStatus == .playing || player.rate > 0
    }

    func loadVideo(from sourceVideoURL: URL) {
        player.pause()
        player.replaceCurrentItem(with: AVPlayerItem(url: sourceVideoURL))
        seek(to: 0)
    }

    func seek(to time: Double) {
        let targetTime = CMTime(seconds: max(time, 0), preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func setTimeUpdateHandler(_ handler: @escaping (Double) -> Void) {
        timeUpdateHandler = handler
    }
}

private extension AVPlayerPreviewDriver {
    func installTimeObserver() {
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self else {
                return
            }

            let seconds = time.seconds
            guard seconds.isFinite else {
                return
            }

            timeUpdateHandler?(seconds)
        }
    }
}
