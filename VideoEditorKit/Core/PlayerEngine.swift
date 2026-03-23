import AVFoundation
import Observation

@MainActor
@Observable
final class PlayerEngine {
    var currentTime: Double = 0
    var duration: Double = 0
    var isPlaying = false

    private var selectedTimeRange: ClosedRange<Double> = 0...0

    init() {}

    func load(duration: Double) throws {
        guard duration.isFinite, duration >= 0 else {
            throw VideoEditorError.invalidVideoDuration
        }

        self.duration = duration
        selectedTimeRange = normalizedSelectedTimeRange(selectedTimeRange)
        currentTime = TimeRangeEngine.clampTime(currentTime, to: selectedTimeRange)
        isPlaying = false
    }

    func load(asset: AVAsset) async throws {
        do {
            let loadedDuration = try await asset.load(.duration).seconds
            try load(duration: loadedDuration)
        } catch let error as VideoEditorError {
            throw error
        } catch {
            throw VideoEditorError.invalidAsset
        }
    }

    func play() {
        currentTime = TimeRangeEngine.clampTime(currentTime, to: selectedTimeRange)

        guard duration > 0, currentTime < selectedTimeRange.upperBound else {
            isPlaying = false
            return
        }

        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func seek(to time: Double, in selectedTimeRange: ClosedRange<Double>) {
        self.selectedTimeRange = normalizedSelectedTimeRange(selectedTimeRange)
        currentTime = TimeRangeEngine.clampTime(time, to: self.selectedTimeRange)

        if currentTime >= self.selectedTimeRange.upperBound {
            isPlaying = false
        }
    }

    func handleSelectedTimeRangeChange(_ selectedTimeRange: ClosedRange<Double>) {
        self.selectedTimeRange = normalizedSelectedTimeRange(selectedTimeRange)
        currentTime = TimeRangeEngine.clampTime(currentTime, to: self.selectedTimeRange)

        if currentTime >= self.selectedTimeRange.upperBound {
            isPlaying = false
        }
    }

    func handlePlaybackTimeUpdate(_ time: Double) {
        currentTime = TimeRangeEngine.clampTime(time, to: selectedTimeRange)

        if time >= selectedTimeRange.upperBound {
            isPlaying = false
        }
    }
}

private extension PlayerEngine {
    var fullTimeRange: ClosedRange<Double> {
        0...duration
    }

    func normalizedSelectedTimeRange(
        _ selectedTimeRange: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        let validRange = fullTimeRange
        let overlapLowerBound = max(selectedTimeRange.lowerBound, validRange.lowerBound)
        let overlapUpperBound = min(selectedTimeRange.upperBound, validRange.upperBound)

        guard overlapLowerBound < overlapUpperBound || validRange.lowerBound == validRange.upperBound else {
            return validRange
        }

        let lowerBound = TimeRangeEngine.clampTime(selectedTimeRange.lowerBound, to: validRange)
        let upperBound = TimeRangeEngine.clampTime(selectedTimeRange.upperBound, to: validRange)
        return lowerBound...upperBound
    }
}
