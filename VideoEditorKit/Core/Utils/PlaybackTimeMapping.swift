//
//  PlaybackTimeMapping.swift
//  VideoEditorKit
//
//  Created by OpenAI Codex on 27.03.2026.
//

import Foundation

enum PlaybackTimeMapping {

    // MARK: - Public Methods

    static func timelineTimePreservingSourcePosition(
        timelineTime: Double,
        previousRate: Float,
        newRate: Float,
        newRange: ClosedRange<Double>,
        originalDuration: Double
    ) -> Double {
        let resolvedOriginalDuration = max(originalDuration, .zero)
        let sourceTime = timelineTime.clamped(
            to: .zero...resolvedOriginalDuration
        )
        _ = previousRate
        _ = newRate

        return sourceTime.clamped(to: newRange)
    }

    static func scaledTimelineRange(
        sourceRange: ClosedRange<Double>,
        rate: Float,
        originalDuration: Double
    ) -> ClosedRange<Double> {
        let resolvedOriginalDuration = max(originalDuration, .zero)
        let resolvedRate = Double(normalizedRate(rate))
        let clampedLowerBound = sourceRange.lowerBound.clamped(to: 0...resolvedOriginalDuration)
        let clampedUpperBound = sourceRange.upperBound.clamped(
            to: clampedLowerBound...resolvedOriginalDuration
        )

        return (clampedLowerBound / resolvedRate)...(clampedUpperBound / resolvedRate)
    }

    // MARK: - Private Methods

    private static func normalizedRate(_ rate: Float) -> Float {
        guard rate.isFinite, rate > 0 else { return 1 }
        return rate
    }

}
