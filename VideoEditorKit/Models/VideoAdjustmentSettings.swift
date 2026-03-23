import Foundation

struct VideoAdjustmentSettings: Equatable, Sendable {
    var playbackRate: Double
    var rotation: VideoRotation
    var isMirrored: Bool
    var filterName: String?
    var colorCorrection: VideoColorCorrection
    var frameStyle: VideoFrameStyle?

    init(
        playbackRate: Double = 1,
        rotation: VideoRotation = .degrees0,
        isMirrored: Bool = false,
        filterName: String? = nil,
        colorCorrection: VideoColorCorrection = .init(),
        frameStyle: VideoFrameStyle? = nil
    ) {
        self.playbackRate = Self.normalizedPlaybackRate(playbackRate)
        self.rotation = rotation
        self.isMirrored = isMirrored
        self.filterName = Self.normalizedFilterName(filterName)
        self.colorCorrection = colorCorrection
        self.frameStyle = frameStyle.map {
            VideoFrameStyle(
                backgroundColor: $0.backgroundColor,
                scale: $0.scale
            )
        }
    }
}

extension VideoAdjustmentSettings {
    nonisolated func outputDuration(for selectedTimeRange: ClosedRange<Double>) -> Double {
        let duration = max(selectedTimeRange.upperBound - selectedTimeRange.lowerBound, 0)
        return duration / playbackRate
    }

    nonisolated static func normalizedPlaybackRate(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else {
            return 1
        }

        return min(max(value, 0.25), 4)
    }

    nonisolated static func normalizedFilterName(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
