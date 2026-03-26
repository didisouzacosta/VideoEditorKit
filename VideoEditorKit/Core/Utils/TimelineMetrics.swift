//
//  TimelineMetrics.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 26.03.2026.
//

import CoreGraphics

struct TimelineMetrics {

    // MARK: - Public Properties

    let originalDuration: Double
    let playbackRange: ClosedRange<Double>
    let currentTime: Double
    let width: CGFloat
    let handleInset: CGFloat
    let minimumX: CGFloat

    // MARK: - Private Properties

    private var clampedCurrentTime: Double {
        currentTime.clamped(to: playbackRange)
    }

    private var rangeStartX: CGFloat {
        (CGFloat(playbackRange.lowerBound / originalDuration) * width) + handleInset
    }

    private var rangeEndX: CGFloat {
        (CGFloat(playbackRange.upperBound / originalDuration) * width) - handleInset
    }

    // MARK: - Initializer

    init(
        originalDuration: Double,
        playbackRange: ClosedRange<Double>,
        currentTime: Double,
        width: CGFloat,
        handleInset: CGFloat = 4,
        minimumX: CGFloat = 2
    ) {
        self.originalDuration = originalDuration
        self.playbackRange = playbackRange
        self.currentTime = currentTime
        self.width = width
        self.handleInset = handleInset
        self.minimumX = minimumX
    }

    // MARK: - Public Methods

    func playbackPositionX() -> CGFloat {
        guard originalDuration > 0, width > 0 else { return minimumX }
        guard rangeEndX > rangeStartX else {
            return min(max(rangeStartX, minimumX), width - minimumX)
        }

        let absoluteProgress = clampedCurrentTime / originalDuration
        let positionX = CGFloat(absoluteProgress) * width

        return min(max(positionX, rangeStartX), rangeEndX)
    }

    func currentClipTime() -> Double {
        max(clampedCurrentTime - playbackRange.lowerBound, 0)
    }

    func playbackTime(for locationX: CGFloat) -> Double {
        guard width > 0, originalDuration > 0 else {
            return playbackRange.lowerBound
        }

        let clampedX = min(max(locationX, 0), width)
        let progress = clampedX / width
        let time = Double(progress) * originalDuration

        return time.clamped(to: playbackRange)
    }

    func badgePositionX(for badgeWidth: CGFloat, minimumHalfWidth: CGFloat = 24) -> CGFloat {
        let badgeHalfWidth = max(badgeWidth / 2, minimumHalfWidth)

        return min(
            max(playbackPositionX(), badgeHalfWidth),
            max(width - badgeHalfWidth, badgeHalfWidth)
        )
    }

}
