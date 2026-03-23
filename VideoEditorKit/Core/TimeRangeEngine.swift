import Foundation

struct TimeRangeEngine {
    nonisolated static func resolve(
        videoDuration: Double,
        currentSelection: ClosedRange<Double>,
        preset: ExportPreset
    ) -> TimeRangeResult {
        let normalizedDuration = max(videoDuration, 0)
        let validUpperBound = min(normalizedDuration, preset.maxDuration)
        let validRange = 0...validUpperBound

        return TimeRangeResult(
            validRange: validRange,
            selectedRange: normalizedSelection(currentSelection, in: validRange),
            isVideoTooShort: normalizedDuration < preset.minDuration,
            exceedsMaximum: normalizedDuration > preset.maxDuration
        )
    }

    nonisolated static func clampTime(
        _ time: Double,
        to selectedRange: ClosedRange<Double>
    ) -> Double {
        min(max(time, selectedRange.lowerBound), selectedRange.upperBound)
    }

    nonisolated private static func normalizedSelection(
        _ currentSelection: ClosedRange<Double>,
        in validRange: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        let overlapLowerBound = max(currentSelection.lowerBound, validRange.lowerBound)
        let overlapUpperBound = min(currentSelection.upperBound, validRange.upperBound)

        guard overlapLowerBound < overlapUpperBound || validRange.lowerBound == validRange.upperBound else {
            return validRange
        }

        let lowerBound = clampTime(currentSelection.lowerBound, to: validRange)
        let upperBound = clampTime(currentSelection.upperBound, to: validRange)
        return lowerBound...upperBound
    }
}
