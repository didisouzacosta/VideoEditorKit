import Foundation

struct TimelineInteractionEngine {
    nonisolated static func progress(
        for time: Double,
        in validRange: ClosedRange<Double>
    ) -> Double {
        let rangeDuration = validRange.upperBound - validRange.lowerBound
        guard rangeDuration > 0 else {
            return 0
        }

        let clampedTime = min(max(time, validRange.lowerBound), validRange.upperBound)
        return (clampedTime - validRange.lowerBound) / rangeDuration
    }

    nonisolated static func time(
        for progress: Double,
        in validRange: ClosedRange<Double>
    ) -> Double {
        let clampedProgress = min(max(progress, 0), 1)
        let rangeDuration = validRange.upperBound - validRange.lowerBound

        guard rangeDuration > 0 else {
            return validRange.lowerBound
        }

        return validRange.lowerBound + (clampedProgress * rangeDuration)
    }

    nonisolated static func selectionByUpdatingLowerBound(
        progress: Double,
        currentSelection: ClosedRange<Double>,
        validRange: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        let proposedLowerBound = time(for: progress, in: validRange)
        let clampedLowerBound = min(proposedLowerBound, currentSelection.upperBound)
        return clampedLowerBound...currentSelection.upperBound
    }

    nonisolated static func selectionByUpdatingUpperBound(
        progress: Double,
        currentSelection: ClosedRange<Double>,
        validRange: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        let proposedUpperBound = time(for: progress, in: validRange)
        let clampedUpperBound = max(proposedUpperBound, currentSelection.lowerBound)
        return currentSelection.lowerBound...clampedUpperBound
    }
}
