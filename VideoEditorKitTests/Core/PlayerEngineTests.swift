import Testing
@testable import VideoEditorKit

@MainActor
struct PlayerEngineTests {

    @Test func loadDurationPublishesPlayerState() throws {
        let player = PlayerEngine()

        try player.load(duration: 120)

        #expect(player.duration == 120)
        #expect(player.currentTime == 0)
        #expect(player.isPlaying == false)
    }

    @Test func seekBelowSelectedRangeClampsToLowerBound() throws {
        let player = PlayerEngine()
        try player.load(duration: 120)

        player.seek(to: -5, in: 10...40)

        #expect(player.currentTime == 10)
    }

    @Test func seekAboveSelectedRangeClampsToUpperBound() throws {
        let player = PlayerEngine()
        try player.load(duration: 120)

        player.seek(to: 55, in: 10...40)

        #expect(player.currentTime == 40)
    }

    @Test func seekInsideSelectedRangePreservesValue() throws {
        let player = PlayerEngine()
        try player.load(duration: 120)

        player.seek(to: 25, in: 10...40)

        #expect(player.currentTime == 25)
    }

    @Test func reducingSelectedRangeClampsCurrentTimeImmediately() throws {
        let player = PlayerEngine()
        try player.load(duration: 120)
        player.seek(to: 80, in: 0...120)

        player.handleSelectedTimeRangeChange(0...60)

        #expect(player.currentTime == 60)
        #expect(player.isPlaying == false)
    }

    @Test func expandingBackToOriginalDoesNotExpandCurrentTimeAutomatically() throws {
        let player = PlayerEngine()
        try player.load(duration: 120)
        player.seek(to: 40, in: 0...60)

        player.handleSelectedTimeRangeChange(0...120)

        #expect(player.currentTime == 40)
    }

    @Test func playbackTimeUpdateStopsAtUpperBoundAndPauses() throws {
        let player = PlayerEngine()
        try player.load(duration: 120)
        player.seek(to: 40, in: 30...60)
        player.play()

        player.handlePlaybackTimeUpdate(75)

        #expect(player.currentTime == 60)
        #expect(player.isPlaying == false)
    }

    @Test func playbackTimeUpdateInsideRangeKeepsPlaybackRunning() throws {
        let player = PlayerEngine()
        try player.load(duration: 120)
        player.seek(to: 40, in: 30...60)
        player.play()

        player.handlePlaybackTimeUpdate(50)

        #expect(player.currentTime == 50)
        #expect(player.isPlaying == true)
    }
}
