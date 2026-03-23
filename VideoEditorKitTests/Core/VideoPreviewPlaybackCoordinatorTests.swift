import AVFoundation
import Foundation
import Testing
@testable import VideoEditorKit

@MainActor
struct VideoPreviewPlaybackCoordinatorTests {

    @Test func loadVideoOnlyTouchesDriverWhenURLChanges() {
        let driver = TestVideoPreviewPlayerDriver()
        let coordinator = VideoPreviewPlaybackCoordinator(driver: driver)
        let firstURL = URL(fileURLWithPath: "/tmp/preview-a.mov")
        let secondURL = URL(fileURLWithPath: "/tmp/preview-b.mov")

        coordinator.loadVideoIfNeeded(from: firstURL)
        coordinator.loadVideoIfNeeded(from: firstURL)
        coordinator.loadVideoIfNeeded(from: secondURL)

        #expect(driver.loadedURLs == [firstURL, secondURL])
    }

    @Test func syncSkipsSeekWhenPlayerIsAlreadyAtRequestedTime() {
        let driver = TestVideoPreviewPlayerDriver(currentTime: 12.02)
        let coordinator = VideoPreviewPlaybackCoordinator(driver: driver)

        coordinator.sync(currentTime: 12, isPlaying: false)

        #expect(driver.seekTimes.isEmpty)
    }

    @Test func syncSeeksWhenRequestedTimeDriftsBeyondTolerance() {
        let driver = TestVideoPreviewPlayerDriver(currentTime: 12.2)
        let coordinator = VideoPreviewPlaybackCoordinator(driver: driver)

        coordinator.sync(currentTime: 12, isPlaying: false)

        #expect(driver.seekTimes == [12])
    }

    @Test func syncOnlyTransitionsPlaybackWhenNeeded() {
        let driver = TestVideoPreviewPlayerDriver(isPlaying: false)
        let coordinator = VideoPreviewPlaybackCoordinator(driver: driver)

        coordinator.sync(currentTime: 0, isPlaying: false)
        coordinator.sync(currentTime: 0, isPlaying: true)
        coordinator.sync(currentTime: 0, isPlaying: true)
        coordinator.sync(currentTime: 0, isPlaying: false)

        #expect(driver.playCallCount == 1)
        #expect(driver.pauseCallCount == 1)
    }

    @Test func forwardsPeriodicTimeUpdatesToConsumer() {
        let driver = TestVideoPreviewPlayerDriver()
        var forwardedTimes: [Double] = []
        _ = VideoPreviewPlaybackCoordinator(driver: driver) { time in
            forwardedTimes.append(time)
        }

        driver.emitTimeUpdate(3.5)
        driver.emitTimeUpdate(7.25)

        #expect(forwardedTimes == [3.5, 7.25])
    }
}

@MainActor
private final class TestVideoPreviewPlayerDriver: VideoPreviewPlayerDriving {
    let player = AVPlayer()
    var currentTime: Double
    var isPlaying: Bool
    private var timeUpdateHandler: ((Double) -> Void)?

    private(set) var loadedURLs: [URL] = []
    private(set) var seekTimes: [Double] = []
    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0

    init(
        currentTime: Double = 0,
        isPlaying: Bool = false
    ) {
        self.currentTime = currentTime
        self.isPlaying = isPlaying
    }

    func loadVideo(from sourceVideoURL: URL) {
        loadedURLs.append(sourceVideoURL)
    }

    func seek(to time: Double) {
        currentTime = time
        seekTimes.append(time)
    }

    func play() {
        isPlaying = true
        playCallCount += 1
    }

    func pause() {
        isPlaying = false
        pauseCallCount += 1
    }

    func setTimeUpdateHandler(_ handler: @escaping (Double) -> Void) {
        timeUpdateHandler = handler
    }

    func emitTimeUpdate(_ time: Double) {
        currentTime = time
        timeUpdateHandler?(time)
    }
}
